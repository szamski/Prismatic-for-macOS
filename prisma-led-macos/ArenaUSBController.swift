import Foundation
import IOKit
import IOKit.hid

/// A plain 0–255 RGB triple.
struct RGB: Equatable, Codable {
    var red: Int
    var green: Int
    var blue: Int

    static let black = RGB(red: 0, green: 0, blue: 0)

    func scaled(by brightness: Double) -> RGB {
        let b = max(0, min(1, brightness))
        return RGB(
            red: Int((Double(red) * b).rounded()),
            green: Int((Double(green) * b).rounded()),
            blue: Int((Double(blue) * b).rounded())
        )
    }
}

enum ArenaError: LocalizedError {
    case notFound
    case openFailed(Int32)
    case writeFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "SteelSeries Arena 7 not found. Connect the speakers via USB."
        case .openFailed(let code):
            return String(format: "Couldn't open the device (0x%08X). Quit SteelSeries GG if it's running.", UInt32(bitPattern: code))
        case .writeFailed(let code):
            return String(format: "Failed to send data to the device (0x%08X).", UInt32(bitPattern: code))
        }
    }
}

/// Talks directly to the SteelSeries Arena 7 over USB HID — no SteelSeries GG required.
///
/// Protocol reverse-engineered from a USBPcap capture: the lighting command is an
/// HID **Output report, ID 0x06** (sent as a control SET_REPORT). The 64-byte buffer is:
///
///   [0x06][cmd][zone0…][zone1…][zone2…][zone3…][0x0F][00 pad]
///
///   cmd 0xA1 = set static colors, cmd 0x09 = off
///   each zone = 6 bytes: [R][G][B][0x01][0x1E][brightness 0…10]
///   zone order: 0 = left base, 1 = left rear, 2 = right base, 3 = right rear
///
/// On macOS the report ID is included as the first byte of the buffer AND passed as
/// the reportID argument (this is what the device accepts).
final class ArenaUSBController {
    static let vendorID = 0x1038
    static let productID = 0x1A00
    static let usagePage = 0xFFC0
    private static let reportID: CFIndex = 0x06
    private static let reportLength = 64

    private let manager: IOHIDManager
    private var device: IOHIDDevice?

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    var isConnected: Bool { device != nil }

    /// Finds and opens the Arena 7 vendor interface. Throws on failure.
    func connect() throws {
        if device != nil { return }
        // Match only the Arena 7 vendor interface so the HID manager never touches
        // keyboards or other input devices. Enumeration doesn't require opening the
        // manager; only the per-device IOHIDDeviceOpen below needs Input Monitoring.
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: Self.vendorID,
            kIOHIDProductIDKey: Self.productID,
            kIOHIDPrimaryUsagePageKey: Self.usagePage,
        ] as CFDictionary)

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let match = devices.first else {
            throw ArenaError.notFound
        }

        let result = IOHIDDeviceOpen(match, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else { throw ArenaError.openFailed(result) }
        device = match
    }

    func disconnect() {
        if let device {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device = nil
    }

    /// Sets all four zones. `zones` must be [leftBase, leftRear, rightBase, rightRear].
    /// `brightness` is 0…10 (hardware scale).
    func setZones(_ zones: [RGB], brightness: Int) throws {
        precondition(zones.count == 4)
        let bri = UInt8(max(0, min(10, brightness)))
        var report = [UInt8](repeating: 0, count: Self.reportLength)
        report[0] = 0x06        // report ID
        report[1] = 0xA1        // command: set static colors
        for i in 0..<4 {
            let zone = zones[i]
            let o = 2 + i * 6
            report[o] = UInt8(clamping: zone.red)
            report[o + 1] = UInt8(clamping: zone.green)
            report[o + 2] = UInt8(clamping: zone.blue)
            report[o + 3] = 0x01
            report[o + 4] = 0x1E
            report[o + 5] = bri
        }
        report[26] = 0x0F       // terminator
        try send(report)
    }

    /// Turns all LEDs off by setting every zone to black at zero brightness
    /// (the dedicated 0x09 "off" command isn't reliably honored over USB).
    func turnOff() throws {
        try setZones([.black, .black, .black, .black], brightness: 0)
    }

    private func send(_ report: [UInt8]) throws {
        guard let device else { throw ArenaError.notFound }
        let result = report.withUnsafeBufferPointer { buffer in
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, Self.reportID, buffer.baseAddress!, report.count)
        }
        guard result == kIOReturnSuccess else { throw ArenaError.writeFailed(result) }
    }
}
