#!/usr/bin/env swift
//
// hid-probe.swift — enumerate SteelSeries (VID 0x1038) USB HID devices and dump
// their report structure (report IDs, sizes, usages). Run this with the Arena 7
// connected over USB to learn which feature/output reports drive the lighting.
//
//   swift tools/hid-probe.swift
//
// This is a diagnostic tool, separate from the app target.

import Foundation
import IOKit
import IOKit.hid

let steelSeriesVID = 0x1038

func prop(_ device: IOHIDDevice, _ key: String) -> Any? {
    IOHIDDeviceGetProperty(device, key as CFString)
}

func intProp(_ device: IOHIDDevice, _ key: String) -> Int? {
    (prop(device, key) as? NSNumber)?.intValue
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(manager, nil)
let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
if openResult != kIOReturnSuccess {
    FileHandle.standardError.write("⚠️  IOHIDManagerOpen failed (\(String(format: "0x%08x", openResult))). Try running with sudo.\n".data(using: .utf8)!)
}

guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
    print("No HID devices found.")
    exit(1)
}

let steelSeriesDevices = deviceSet.filter { intProp($0, kIOHIDVendorIDKey) == steelSeriesVID }

if steelSeriesDevices.isEmpty {
    print("❌ No SteelSeries (VID 0x1038) HID devices found.")
    print("   Make sure the Arena 7 is connected over USB (not just Bluetooth) and powered on.")
    print("   \(deviceSet.count) total HID devices are visible.")
    exit(0)
}

print("✅ Found \(steelSeriesDevices.count) SteelSeries HID interface(s):\n")

// Element type → readable name.
func typeName(_ type: IOHIDElementType) -> String {
    switch type {
    case kIOHIDElementTypeInput_Misc, kIOHIDElementTypeInput_Button,
         kIOHIDElementTypeInput_Axis, kIOHIDElementTypeInput_ScanCodes:
        return "Input"
    case kIOHIDElementTypeOutput: return "Output"
    case kIOHIDElementTypeFeature: return "Feature"
    case kIOHIDElementTypeCollection: return "Collection"
    default: return "Other"
    }
}

for device in steelSeriesDevices.sorted(by: { (intProp($0, kIOHIDProductIDKey) ?? 0) < (intProp($1, kIOHIDProductIDKey) ?? 0) }) {
    let pid = intProp(device, kIOHIDProductIDKey) ?? 0
    let product = prop(device, kIOHIDProductKey) as? String ?? "?"
    let usagePage = intProp(device, kIOHIDPrimaryUsagePageKey) ?? 0
    let usage = intProp(device, kIOHIDPrimaryUsageKey) ?? 0
    let maxFeature = intProp(device, kIOHIDMaxFeatureReportSizeKey) ?? 0
    let maxOutput = intProp(device, kIOHIDMaxOutputReportSizeKey) ?? 0
    let maxInput = intProp(device, kIOHIDMaxInputReportSizeKey) ?? 0

    print("──────────────────────────────────────────────")
    print("Product:      \(product)")
    print(String(format: "VID:PID:      0x%04X:0x%04X", steelSeriesVID, pid))
    print(String(format: "UsagePage:    0x%02X  Usage: 0x%02X", usagePage, usage))
    print("Max report:   feature=\(maxFeature) output=\(maxOutput) input=\(maxInput) bytes")

    // Group elements by report ID + type, tracking the largest bit position seen.
    struct ReportInfo { var maxBits = 0; var usages = Set<Int>() }
    var reports: [String: ReportInfo] = [:]

    if let elements = IOHIDDeviceCopyMatchingElements(device, nil, 0) as? [IOHIDElement] {
        for element in elements {
            let type = IOHIDElementGetType(element)
            guard type == kIOHIDElementTypeFeature || type == kIOHIDElementTypeOutput
                || type == kIOHIDElementTypeInput_Misc || type == kIOHIDElementTypeInput_Button
                || type == kIOHIDElementTypeInput_Axis else { continue }
            let reportID = IOHIDElementGetReportID(element)
            let reportSize = IOHIDElementGetReportSize(element)   // bits per element
            let reportCount = IOHIDElementGetReportCount(element) // element count
            let elUsage = Int(IOHIDElementGetUsage(element))
            let key = "\(typeName(type)) report 0x\(String(format: "%02X", reportID))"
            var info = reports[key] ?? ReportInfo()
            info.maxBits += Int(reportSize) * Int(reportCount)
            info.usages.insert(elUsage)
            reports[key] = info
        }
    }

    if reports.isEmpty {
        print("  (no input/output/feature elements enumerated)")
    } else {
        print("  Reports:")
        for key in reports.keys.sorted() {
            let info = reports[key]!
            let bytes = (info.maxBits + 7) / 8
            print("    \(key): ~\(bytes) data bytes")
        }
    }

    // Raw HID report descriptor, if exposed (useful for offline analysis).
    if let descriptor = prop(device, "ReportDescriptor") as? Data ?? prop(device, kIOHIDReportDescriptorKey as String) as? Data {
        let hex = descriptor.map { String(format: "%02x", $0) }.joined()
        print("  ReportDescriptor (\(descriptor.count) bytes): \(hex)")
    }
    print("")
}

print("Done. The 'Feature' or 'Output' report with the largest data size is the")
print("most likely lighting channel. Next: capture GG setting a color, or read GG's")
print("device-definition files, to learn the byte layout (zone order + RGB offsets).")
