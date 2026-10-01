import XCTest
import CoreBluetooth
@testable import Strand

/// Bluetooth switched off, or bluetoothd resetting, ends the link, but CoreBluetooth generally invalidates
/// the peripheral rather than calling didDisconnect. The session used to outlive the radio, so the
/// reconnect on poweredOn skipped the handshake and history never synced. These pin which radio states
/// end a link and when there is a session worth tearing down.
final class RadioDropTeardownTests: XCTestCase {

    func testPoweredOffAndResettingEndTheLink() {
        XCTAssertTrue(BLEManager.radioStateEndsLink(.poweredOff))
        XCTAssertTrue(BLEManager.radioStateEndsLink(.resetting))
    }

    /// Left to the existing banner handling; none of these is a radio that just dropped a live link.
    func testOtherStatesAreLeftAlone() {
        for s in [CBManagerState.poweredOn, .unknown, .unauthorized, .unsupported] {
            XCTAssertFalse(BLEManager.radioStateEndsLink(s), "\(s.rawValue)")
        }
    }

    /// The case the fix exists for: a connected, bonded, handshaken session.
    func testALiveSessionIsTornDown() {
        XCTAssertTrue(BLEManager.radioDropNeedsTeardown(hasPeripheral: true, connected: true, bonded: true,
                                                        handshakeDone: true, linkUp: true))
    }

    /// Any one sign of a session is enough: the flags that wedge the reconnect are exactly the ones
    /// that can outlive `connected`.
    func testAnySingleSignOfASessionIsEnough() {
        XCTAssertTrue(BLEManager.radioDropNeedsTeardown(hasPeripheral: true, connected: false, bonded: true,
                                                        handshakeDone: false, linkUp: false))
        XCTAssertTrue(BLEManager.radioDropNeedsTeardown(hasPeripheral: true, connected: false, bonded: false,
                                                        handshakeDone: true, linkUp: false))
        XCTAssertTrue(BLEManager.radioDropNeedsTeardown(hasPeripheral: true, connected: false, bonded: false,
                                                        handshakeDone: false, linkUp: true))
    }

    /// A standing connect still waiting (peripheral held, no session) has nothing to tear down.
    func testAWaitingStandingConnectHasNothingToTearDown() {
        XCTAssertFalse(BLEManager.radioDropNeedsTeardown(hasPeripheral: true, connected: false, bonded: false,
                                                         handshakeDone: false, linkUp: false))
    }

    func testNoPeripheralNothingToTearDown() {
        XCTAssertFalse(BLEManager.radioDropNeedsTeardown(hasPeripheral: false, connected: true, bonded: true,
                                                         handshakeDone: true, linkUp: true))
    }
}
