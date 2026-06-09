#!/usr/bin/env swift
//
// led-probe.swift — interactive HID prober for the SteelSeries Arena 7.
//
// Opens the Arena 7 vendor interface (UsagePage 0xFFC0) and lets you fire
// candidate Feature/Output reports while watching the speakers, to reverse the
// lighting protocol (report 0x06).
//
//   swift tools/led-probe.swift
//
// REPL commands (hex bytes may include spaces):
//   f <idHex> <hex...>   send a FEATURE report with report-id idHex
//   o <idHex> <hex...>   send an OUTPUT report with report-id idHex
//   g <idHex> <len>      GET a feature report of <len> bytes (dump current)
//   pad <n>              right-pad every sent payload with 0x00 up to n bytes
//   seize                reopen the device in exclusive (seize) mode
//   q                    quit
//
// Examples:
//   pad 64
//   f 06 06 00 ff 00 00     (try: cmd 0x06, then guesses…)
//
// Diagnostic tool, separate from the app target.

import Foundation
import IOKit
import IOKit.hid

let VID = 0x1038
let TARGET_USAGE_PAGE = 0xFFC0   // vendor lighting/control interface

func intProp(_ d: IOHIDDevice, _ k: String) -> Int? { (IOHIDDeviceGetProperty(d, k as CFString) as? NSNumber)?.intValue }
func strProp(_ d: IOHIDDevice, _ k: String) -> String? { IOHIDDeviceGetProperty(d, k as CFString) as? String }

func err(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }
func ret(_ r: IOReturn) -> String { String(format: "0x%08X", UInt32(bitPattern: r)) }

// Parse a hex string like "06 00 ff" or "0600ff" into bytes.
func parseHex(_ s: String) -> [UInt8]? {
    let cleaned = s.replacingOccurrences(of: ",", with: " ")
    var bytes: [UInt8] = []
    let tokens = cleaned.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
    if tokens.count == 1, tokens[0].count > 2, tokens[0].count % 2 == 0 {
        // contiguous hex
        let h = tokens[0]
        var i = h.startIndex
        while i < h.endIndex {
            let j = h.index(i, offsetBy: 2)
            guard let b = UInt8(h[i..<j], radix: 16) else { return nil }
            bytes.append(b); i = j
        }
        return bytes
    }
    for t in tokens {
        guard let b = UInt8(t, radix: 16) else { return nil }
        bytes.append(b)
    }
    return bytes
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(manager, nil)
_ = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
guard let all = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
    err("No HID devices."); exit(1)
}

let candidates = all.filter {
    intProp($0, kIOHIDVendorIDKey) == VID && intProp($0, kIOHIDPrimaryUsagePageKey) == TARGET_USAGE_PAGE
}

guard var device = candidates.first else {
    err("❌ Arena 7 vendor interface (UsagePage 0xFFC0) not found.")
    err("   Connected SteelSeries interfaces:")
    for d in all where intProp(d, kIOHIDVendorIDKey) == VID {
        err(String(format: "     %@  pid=0x%04X usagePage=0x%04X", strProp(d, kIOHIDProductKey) ?? "?", intProp(d, kIOHIDProductIDKey) ?? 0, intProp(d, kIOHIDPrimaryUsagePageKey) ?? 0))
    }
    err("   If empty, make sure the SteelSeries engine is stopped so it releases the device:")
    err("     sudo \"/Applications/SteelSeries GG/SteelSeries GG.app/Contents/Resources/stopSSENextCore.sh\"")
    exit(2)
}

func openDevice(seize: Bool) -> Bool {
    let opts = seize ? IOOptionBits(kIOHIDOptionsTypeSeizeDevice) : IOOptionBits(kIOHIDOptionsTypeNone)
    let r = IOHIDDeviceOpen(device, opts)
    if r != kIOReturnSuccess {
        err("⚠️  IOHIDDeviceOpen(\(seize ? "seize" : "shared")) returned \(ret(r))")
        return false
    }
    return true
}

let product = strProp(device, kIOHIDProductKey) ?? "?"
let pid = intProp(device, kIOHIDProductIDKey) ?? 0
print(String(format: "✅ Opening %@ (0x%04X:0x%04X) vendor interface…", product, VID, pid))
if !openDevice(seize: false) {
    err("   Trying seize mode…")
    if !openDevice(seize: true) {
        err("   Could not open. Stop the SteelSeries engine first (see hint above) and retry.")
        exit(3)
    }
}
print("Connected. Type 'q' to quit. Watch the speakers as you send reports.\n")

var padTo = 0

func send(feature: Bool, reportID: UInt8, payload: [UInt8]) {
    var buf = payload
    if padTo > buf.count { buf.append(contentsOf: [UInt8](repeating: 0, count: padTo - buf.count)) }
    let type: IOHIDReportType = feature ? kIOHIDReportTypeFeature : kIOHIDReportTypeOutput
    let r = buf.withUnsafeBufferPointer {
        IOHIDDeviceSetReport(device, type, CFIndex(reportID), $0.baseAddress!, CFIndex(buf.count))
    }
    let hex = buf.prefix(24).map { String(format: "%02x", $0) }.joined(separator: " ")
    print("  \(feature ? "FEATURE" : "OUTPUT ") id=0x\(String(format: "%02x", reportID)) len=\(buf.count) [\(hex)\(buf.count > 24 ? " …" : "")] -> \(r == kIOReturnSuccess ? "OK ✅" : "ERR \(ret(r)) ❌")")
}

func getReport(reportID: UInt8, len: Int) {
    var buf = [UInt8](repeating: 0, count: len)
    var length = CFIndex(len)
    let r = buf.withUnsafeMutableBufferPointer {
        IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(reportID), $0.baseAddress!, &length)
    }
    if r == kIOReturnSuccess {
        let hex = buf.prefix(Int(length)).map { String(format: "%02x", $0) }.joined(separator: " ")
        print("  GET feature id=0x\(String(format: "%02x", reportID)) len=\(length): \(hex)")
    } else {
        print("  GET feature id=0x\(String(format: "%02x", reportID)) -> ERR \(ret(r)) ❌")
    }
}

while let raw = readLine() {
    let line = raw.trimmingCharacters(in: .whitespaces)
    if line.isEmpty { continue }
    let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
    let cmd = parts[0].lowercased()
    let rest = parts.count > 1 ? parts[1] : ""

    switch cmd {
    case "q", "quit", "exit":
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)); exit(0)
    case "pad":
        padTo = Int(rest.trimmingCharacters(in: .whitespaces)) ?? 0
        print("  pad length = \(padTo)")
    case "seize":
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        _ = openDevice(seize: true)
        print("  reopened in seize mode")
    case "sleep":
        let secs = Double(rest.trimmingCharacters(in: .whitespaces)) ?? 0
        FileHandle.standardOutput.synchronizeFile()
        Thread.sleep(forTimeInterval: secs)
    case "say":
        print("  >>> \(rest)")
    case "f", "o":
        let toks = rest.split(separator: " ", maxSplits: 1).map(String.init)
        guard toks.count >= 1, let id = UInt8(toks[0], radix: 16) else { print("  usage: \(cmd) <idHex> <hex...>"); continue }
        let payloadStr = toks.count > 1 ? toks[1] : ""
        guard let payload = parseHex(payloadStr) else { print("  bad hex"); continue }
        send(feature: cmd == "f", reportID: id, payload: payload)
    case "g":
        let toks = rest.split(separator: " ").map(String.init)
        guard toks.count == 2, let id = UInt8(toks[0], radix: 16), let len = Int(toks[1]) else { print("  usage: g <idHex> <len>"); continue }
        getReport(reportID: id, len: len)
    case "fill":
        // fill <f|o> <idHex> <rgbHex> <totalBytes>  — repeat rgbHex up to totalBytes, then send
        let toks = rest.split(separator: " ").map(String.init)
        guard toks.count == 4, let id = UInt8(toks[1], radix: 16),
              let unit = parseHex(toks[2]), !unit.isEmpty, let total = Int(toks[3]) else {
            print("  usage: fill <f|o> <idHex> <rgbHex> <totalBytes>"); continue
        }
        var payload: [UInt8] = []
        while payload.count < total { payload.append(unit[payload.count % unit.count]) }
        send(feature: toks[0].lowercased() == "f", reportID: id, payload: payload)
    default:
        print("  commands: f/o <idHex> <hex…> | g <idHex> <len> | pad <n> | seize | q")
    }
}
IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
