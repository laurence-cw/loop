import XCTest
@testable import Strand

/// Two fixes from one field WHOOP 4.0's log (twin of the Kotlin `StrapClockAndLivenessTest`):
/// the clock is re-set when the strap reports BOOT / RTC_LOST, and an unarmed 4.0 is not bounced every
/// two minutes for being quiet.
final class StrapClockAndLivenessTests: XCTestCase {

    // MARK: shouldRestoreStrapClock

    /// The field case: a reboot on a flat battery over a live, bonded link sets the clock at once.
    func testAClockLossOnALiveBondedLinkRestoresTheClock() {
        XCTAssertTrue(BLEManager.shouldRestoreStrapClock(connected: true, bonded: true, secondsSinceLastRestore: nil))
    }

    /// A reboot reports BOOT and RTC_LOST back to back; the second within 30 s does nothing more.
    func testTheSecondEventOfAPairDoesNotRepeatTheSet() {
        XCTAssertFalse(BLEManager.shouldRestoreStrapClock(connected: true, bonded: true, secondsSinceLastRestore: 0.2))
        XCTAssertTrue(BLEManager.shouldRestoreStrapClock(connected: true, bonded: true, secondsSinceLastRestore: 30))
    }

    /// No link, or no bond, carries no commands: nothing is sent.
    func testNoLinkOrNoBondSendsNothing() {
        XCTAssertFalse(BLEManager.shouldRestoreStrapClock(connected: false, bonded: true, secondsSinceLastRestore: nil))
        XCTAssertFalse(BLEManager.shouldRestoreStrapClock(connected: true, bonded: false, secondsSinceLastRestore: nil))
    }

    // MARK: livenessBounceFuseSeconds

    /// An armed 4.0 streams every second, so two minutes of silence is a real stall.
    func testAnArmedWhoop4KeepsTheTightFuse() {
        XCTAssertEqual(BLEManager.livenessBounceFuseSeconds(family: .whoop4, realtimeArmed: true), 120)
    }

    /// The field case: unarmed, a healthy 4.0 is quiet between ~8-min battery events. 100 of 112 drops in
    /// a day were the 120 s fuse firing on that quiet.
    func testAnUnarmedWhoop4GetsTheWideFuse() {
        XCTAssertEqual(BLEManager.livenessBounceFuseSeconds(family: .whoop4, realtimeArmed: false), 600)
    }

    /// The 5/MG family is unchanged (#1414), armed or not.
    func testWhoop5IsUnchanged() {
        XCTAssertEqual(BLEManager.livenessBounceFuseSeconds(family: .whoop5, realtimeArmed: true), 600)
        XCTAssertEqual(BLEManager.livenessBounceFuseSeconds(family: .whoop5, realtimeArmed: false), 600)
    }

    /// The wide fuse must still outlast the 4.0's own ~8-min battery cadence, or it bounces healthy links.
    func testTheWideFuseOutlastsTheBatteryEventCadence() {
        XCTAssertGreaterThan(BLEManager.livenessBounceFuseSeconds(family: .whoop4, realtimeArmed: false), 8 * 60)
    }
}
