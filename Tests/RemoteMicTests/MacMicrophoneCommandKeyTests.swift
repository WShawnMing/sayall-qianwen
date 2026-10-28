import Foundation
import Testing
@testable import RemoteMic

@Suite("Mac microphone physical Command")
struct MacMicrophoneCommandKeyTests {
    @Test func enablingWhileHeldWaitsForReleaseAndAnotherPress() {
        var keys = MacMicrophoneCommandKeys(waitForRelease: true)
        #expect(keys.update(device: 1, pressed: true) == nil)
        #expect(keys.update(device: 2, pressed: true) == nil)
        #expect(keys.update(device: 1, pressed: false) == nil)
        #expect(keys.update(device: 2, pressed: false) == nil)
        #expect(keys.update(device: 1, pressed: true) == true)
        #expect(keys.update(device: 1, pressed: false) == false)
        var stoppedWhileHeld = MacMicrophoneCommandKeys(waitForRelease: true)
        #expect(stoppedWhileHeld.update(device: 1, pressed: true) == nil)
        #expect(stoppedWhileHeld.reset() == false)
    }

    @Test func reportsAreBalancedAcrossKeyboardsAndRemoval() {
        var keys = MacMicrophoneCommandKeys()
        #expect(keys.update(device: 1, pressed: false) == nil)
        #expect(keys.update(device: 1, pressed: true) == true)
        #expect(keys.update(device: 1, pressed: true) == nil)
        #expect(keys.update(device: 2, pressed: true) == nil)
        #expect(keys.update(device: 1, pressed: false) == nil)
        #expect(keys.update(device: 2, pressed: false) == false)
        #expect(keys.update(device: 2, pressed: false) == nil)
        #expect(keys.reset() == false)
        #expect(keys.update(device: 1, pressed: true) == true)
        #expect(keys.reset() == true)
        #expect(keys.update(device: 1, pressed: false) == nil)
    }

    @Test func holdStartsOnceAndReleaseStopsOnlyItsOwnSession() {
        let session = MacMicrophoneCommandSession()
        var starts = 0
        var stops = 0
        session.begin = { starts += 1; return true }
        session.end = { stops += 1 }
        session.update(pressed: true)
        session.update(pressed: true)
        #expect(starts == 1)
        #expect(session.ownsSession)
        session.update(pressed: false)
        session.update(pressed: false)
        #expect(stops == 1)
        #expect(!session.ownsSession)
        session.update(pressed: true)
        session.cancel()
        session.update(pressed: false)
        #expect(starts == 2)
        #expect(stops == 2)
    }

    @Test func busyRemoteOrManualMicrophoneIsNotStoppedByPhysicalRelease() {
        let session = MacMicrophoneCommandSession()
        var available = false
        var stops = 0
        session.begin = { available }
        session.end = { stops += 1 }
        session.update(pressed: true)
        available = true
        session.update(pressed: false)
        #expect(stops == 0)
        session.update(pressed: true)
        #expect(session.ownsSession)
        // Failure, timeout, or manual stop relinquishes ownership. A later
        // manually started session must survive the old physical key-up.
        session.sessionEnded()
        session.update(pressed: false)
        #expect(stops == 0)
    }

    @Test func localOptInDefaultsOffAndDoesNotTravelWithExport() throws {
        let name = "MacMicrophoneCommandTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        #expect(!settings.macMicrophoneCommandEnabled)
        settings.macMicrophoneCommandEnabled = true
        #expect(AppSettings(defaults: defaults).macMicrophoneCommandEnabled)
        let data = try settings.exportedConfigurationData()
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["macMicrophoneCommandEnabled"] == nil)
        settings.macMicrophoneCommandEnabled = false
        try settings.importConfiguration(from: data)
        #expect(!settings.macMicrophoneCommandEnabled)
    }
}
