import Foundation
import CoreGraphics
import IOKit.hid

/// Observes only keyboard Right GUI (right Command), without seizing a device
/// or changing keyboard events. CGEvent posts from the remote never enter this
/// HID value callback, so a remote voice trigger cannot open the Mac microphone.
final class MacMicrophoneCommandKey {
    var onChange: (Bool) -> Void = { _ in }
    var onUnavailable: () -> Void = {}
    private var manager: IOHIDManager?
    private var permissionTimer: Timer?
    private var keys = MacMicrophoneCommandKeys()

    @discardableResult
    func start() -> Bool {
        guard manager == nil else { return true }
        guard HIDRemoteMonitor.isInputMonitoringGranted else { return false }
        // Enabling or waking while the key is held must not start capture.
        keys = MacMicrophoneCommandKeys(waitForRelease:
            CGEventSource.keyState(.hidSystemState, key: 54))
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
        ] as CFDictionary)
        IOHIDManagerSetInputValueMatching(manager, [
            kIOHIDElementUsagePageKey: kHIDPage_KeyboardOrKeypad,
            kIOHIDElementUsageKey: kHIDUsage_KeyboardRightGUI,
        ] as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, _, value in
            guard result == kIOReturnSuccess, let context else { return }
            let monitor = Unmanaged<MacMicrophoneCommandKey>.fromOpaque(context).takeUnretainedValue()
            let element = IOHIDValueGetElement(value)
            guard IOHIDElementGetUsagePage(element) == kHIDPage_KeyboardOrKeypad,
                  IOHIDElementGetUsage(element) == kHIDUsage_KeyboardRightGUI else { return }
            let device = IOHIDElementGetDevice(element)
            monitor.receive(device: CFHash(device), pressed: IOHIDValueGetIntegerValue(value) != 0)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            let monitor = Unmanaged<MacMicrophoneCommandKey>.fromOpaque(context).takeUnretainedValue()
            monitor.receive(device: CFHash(device), pressed: false)
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            AppLogger.shared.write("MAC COMMAND phase=failed reason=hid_open code=\(result)")
            return false
        }
        self.manager = manager
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, !HIDRemoteMonitor.isInputMonitoringGranted else { return }
            self.onUnavailable()
            self.stop()
        }
        permissionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        AppLogger.shared.write("MAC COMMAND phase=started result=observing_right_command")
        return true
    }

    private func receive(device: UInt, pressed: Bool) {
        guard manager != nil, let edge = keys.update(device: device, pressed: pressed) else { return }
        AppLogger.shared.write("MAC COMMAND phase=observed edge=\(edge ? "down" : "up")")
        onChange(edge)
    }

    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        if let manager {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            self.manager = nil
        }
        if keys.reset() { onChange(false) }
    }

    deinit { stop() }
}

/// Deduplicates reports and balances releases across multiple keyboards.
struct MacMicrophoneCommandKeys {
    private var held = Set<UInt>()
    private var waitForRelease: Bool
    init(waitForRelease: Bool = false) { self.waitForRelease = waitForRelease }
    mutating func update(device: UInt, pressed: Bool) -> Bool? {
        let wasPressed = !held.isEmpty
        if pressed { held.insert(device) } else { held.remove(device) }
        let isPressed = !held.isEmpty
        if waitForRelease {
            if !isPressed { waitForRelease = false }
            return nil
        }
        return wasPressed == isPressed ? nil : isPressed
    }
    mutating func reset() -> Bool {
        let wasPressed = !held.isEmpty && !waitForRelease
        held.removeAll()
        waitForRelease = false
        return wasPressed
    }
}

/// A key release may stop only the session started by that physical key.
final class MacMicrophoneCommandSession {
    var begin: () -> Bool = { false }
    var end: () -> Void = {}
    private var pressed = false
    private(set) var ownsSession = false

    func update(pressed: Bool) {
        guard self.pressed != pressed else { return }
        self.pressed = pressed
        if pressed { ownsSession = begin() }
        else if ownsSession {
            ownsSession = false
            end()
        }
    }

    func sessionEnded() { ownsSession = false }

    func cancel() {
        pressed = false
        guard ownsSession else { return }
        ownsSession = false
        end()
    }
}
