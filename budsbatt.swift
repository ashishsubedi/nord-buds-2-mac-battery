// budsbatt.swift — per-bud battery query for OnePlus Nord Buds 2 on macOS.
//
// Transport: classic Bluetooth SPP/RFCOMM, service "oppointeraction"
// (UUID 00001107-D102-11E1-9B23-00025B00A5A5), RFCOMM channel 15.
// Query:   AA 07 00 00 06 01 <SEQ> 00 00
// Reply:   AA .. 00 00 06 81 <SEQ> .. 00 00 <N> <id> <pct> ...
//   id 01 = left, 02 = right, 03 = case (case only present while buds docked).
//
// Protocol reverse-engineered from Android HCI snoop of HeyMelody traffic.
// Build: swiftc -framework IOBluetooth -o budsbatt budsbatt.swift
// Run:   ./budsbatt   (buds must be Classic-connected to this Mac)
// Output: RESULT L=<n> R=<n> [C=<n>]
//
// Change BUDS_ADDRESS if your buds differ (system_profiler SPBluetoothDataType).

import Foundation
import IOBluetooth

let BUDS_ADDRESS = "84-0F-2A-6F-31-85" // system_profiler SPBluetoothDataType
let RFCOMM_CHANNEL: BluetoothRFCOMMChannelID = 15

class Batt: NSObject {
    var channel: IOBluetoothRFCOMMChannel?
    var buf = Data()
    var gotL: Int? = nil
    var gotR: Int? = nil

    func run() {
        guard let dev = IOBluetoothDevice(addressString: BUDS_ADDRESS) else {
            print("NO-DEVICE"); exit(1)
        }
        var ch: IOBluetoothRFCOMMChannel? = nil
        let r = dev.openRFCOMMChannelSync(&ch, withChannelID: RFCOMM_CHANNEL, delegate: self)
        guard r == kIOReturnSuccess, let c = ch else {
            print("OPEN-FAIL \(r)"); exit(1)
        }
        channel = c
        // battery query, SEQ 0x50 (device echoes it)
        send([0xAA, 0x07, 0x00, 0x00, 0x06, 0x01, 0x50, 0x00, 0x00])
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            if let l = self.gotL, let rr = self.gotR {
                print("RESULT L=\(l) R=\(rr)")
            } else {
                print("TIMEOUT-NO-BATTERY raw=\(self.buf.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }
            exit(0)
        }
        RunLoop.main.run()
    }

    func send(_ b: [UInt8]) {
        var d = Data(b)
        let r = d.withUnsafeMutableBytes { ptr -> IOReturn in
            channel!.writeSync(ptr.baseAddress!, length: UInt16(b.count))
        }
        if r != kIOReturnSuccess { print("TX-FAIL \(r)") }
    }

    @objc func rfcommChannelOpenComplete(_ ch: IOBluetoothRFCOMMChannel!, status: IOReturn) {}
    @objc func rfcommChannelClosed(_ ch: IOBluetoothRFCOMMChannel!) {}
    @objc func rfcommChannelData(_ ch: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let d = Data(bytes: dataPointer, count: dataLength)
        buf.append(d)
        parse()
    }
    func parse() {
        let b = [UInt8](buf)
        var i = 0
        while i + 11 <= b.count {
            if b[i] == 0xAA && b[i+4] == 0x06 && b[i+5] == 0x81 {
                let count = Int(b[i+10])
                guard count >= 2 && count <= 3 else { i += 1; continue }
                let need = 11 + count * 2
                guard i + need <= b.count else { break }
                var l: Int? = nil; var r: Int? = nil; var c: Int? = nil
                for e in 0..<count {
                    let id = b[i+11+e*2]; let v = Int(b[i+12+e*2])
                    guard v <= 100 else { break }
                    if id == 0x01 { l = v } else if id == 0x02 { r = v } else if id == 0x03 { c = v }
                }
                if let l = l, let r = r {
                    gotL = l; gotR = r
                    if let c = c {
                        print("RESULT L=\(l) R=\(r) C=\(c)")
                    } else {
                        print("RESULT L=\(l) R=\(r)")
                    }
                    exit(0)
                }
                i += need
            } else {
                i += 1
            }
        }
    }
}
Batt().run()
