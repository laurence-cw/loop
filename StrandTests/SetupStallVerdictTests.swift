import XCTest
@testable import Strand

/// A link that connects but never bonds and never delivers anything used to sit on "Connecting…" forever:
/// nothing timed it out and, with the link up, nothing reconnected. `setupStallVerdict` decides what the
/// setup deadline does when it fires.
final class SetupStallVerdictTests: XCTestCase {

    private let limit = BLEManager.setupStallBounceLimit

    private func verdict(connected: Bool = true, bonded: Bool = false, data: Bool = false,
                         bounces: Int = 0) -> BLEManager.SetupStallVerdict {
        BLEManager.setupStallVerdict(sameLinkStillConnected: connected, bonded: bonded,
                                     dataSinceConnect: data, bouncesSoFar: bounces, limit: limit)
    }

    /// The bug: connected, no bond, nothing arrived. Reconnect.
    func testAStalledLinkIsBounced() {
        XCTAssertEqual(verdict(), .bounce)
    }

    /// A healthy setup bonded before the deadline.
    func testABondedLinkIsLeftAlone() {
        XCTAssertEqual(verdict(bonded: true), .leave)
    }

    /// The #1635 hello-suppressed 5/MG runs unbonded on live HR by design. Any data at all means it is not
    /// stalled, and bouncing it would undo the suppression (AGENTS.md on `didBond`).
    func testAnUnbondedLinkThatDeliversDataIsLeftAlone() {
        XCTAssertEqual(verdict(data: true), .leave)
    }

    /// The deadline belongs to one link; if that link already ended or another took over, do nothing.
    func testAGoneOrReplacedLinkIsLeftAlone() {
        XCTAssertEqual(verdict(connected: false), .leave)
    }

    /// Bounded: a strap held by another app is not reconnected every 45 s indefinitely.
    func testRetriesStopAtTheLimitAndGuidanceShows() {
        XCTAssertEqual(verdict(bounces: limit - 1), .bounce)
        XCTAssertEqual(verdict(bounces: limit), .giveUp)
        XCTAssertEqual(verdict(bounces: limit + 5), .giveUp)
    }

    /// Exemptions win over the limit: a link that bonds or streams after earlier stalls is fine.
    func testExemptionsWinOverAnExhaustedLimit() {
        XCTAssertEqual(verdict(bonded: true, bounces: limit), .leave)
        XCTAssertEqual(verdict(data: true, bounces: limit), .leave)
    }

    /// Long enough for any healthy setup, short of "forever".
    func testTheDeadlineIsBetweenAHealthySetupAndForever() {
        XCTAssertGreaterThanOrEqual(BLEManager.setupDeadlineSeconds, 30)
        XCTAssertLessThanOrEqual(BLEManager.setupDeadlineSeconds, 120)
    }
}
