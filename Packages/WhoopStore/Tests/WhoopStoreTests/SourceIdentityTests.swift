import XCTest
@testable import WhoopStore

/// Which device a live link's samples belong to (#1881) — the twin of the Kotlin `SourceIdentityTest`,
/// asserting the same inputs and the same answers so the two platforms cannot drift.
///
/// The reported failure is the first case here: with an Oura ring active and a WHOOP merely paired, a
/// WHOOP connection filed 770 `stepSample` and 770 `gravitySample` rows under the ring's id. A ring has no
/// pedometer and no accelerometer, so 100% of those rows were misattributed — and because `hrSample` is
/// written by both paths under one id, contamination there cannot be separated after the fact.
final class SourceIdentityTests: XCTestCase {

    private func row(_ id: String, _ brand: String, _ peripheralId: String?,
                     _ status: DeviceStatus = .paired) -> PairedDevice {
        PairedDevice(id: id, brand: brand, model: "m", peripheralId: peripheralId,
                     sourceKind: .liveBLE, capabilities: [.hr], status: status,
                     addedAt: 0, lastSeenAt: 0)
    }

    private lazy var ring = row("oura-abc", "Oura", "AA:BB:CC:DD:EE:01")
    private lazy var strap = row("whoop-123", "WHOOP", "AA:BB:CC:DD:EE:02")

    /// The reported bug: the ring is active, the STRAP connected, so the strap's id must win.
    func testStrapConnectingWhileRingActiveIsAttributedToTheStrap() {
        XCTAssertEqual(SourceIdentity.resolve(address: "AA:BB:CC:DD:EE:02",
                                              rows: [ring, strap], currentId: "oura-abc"), "whoop-123")
    }

    /// The legacy single-WHOOP path, and the reason this returns nil rather than guessing: the seeded row
    /// has not adopted an address yet. The coordinator adopts one on this same connect, so the NEXT connect
    /// resolves — and until then the id stays exactly what it is today.
    func testUnadoptedRowLeavesTheIdAlone() {
        let legacy = row("my-whoop", "WHOOP", nil)
        XCTAssertNil(SourceIdentity.resolve(address: "AA:BB:CC:DD:EE:02",
                                            rows: [legacy], currentId: "my-whoop"))
    }

    /// No row carries this address — an unknown strap must never claim an existing device's id.
    func testUnknownAddressLeavesTheIdAlone() {
        XCTAssertNil(SourceIdentity.resolve(address: "FF:FF:FF:FF:FF:FF",
                                            rows: [ring, strap], currentId: "oura-abc"))
    }

    /// The inverse of the bug. If a non-WHOOP row somehow matches, re-pointing the WHOOP path's id at it
    /// would file strap samples under a ring — exactly what #1881 reports, arrived at from the other side.
    func testNonWhoopMatchNeverClaimsTheStrapsSamples() {
        XCTAssertNil(SourceIdentity.resolve(address: "AA:BB:CC:DD:EE:01",
                                            rows: [ring, strap], currentId: "whoop-123"))
    }

    /// Already correct — the common path — must not write.
    func testIdAlreadyCorrectResolvesToNothing() {
        XCTAssertNil(SourceIdentity.resolve(address: "AA:BB:CC:DD:EE:02",
                                            rows: [ring, strap], currentId: "whoop-123"))
    }

    /// Neither OS guarantees the case of a UUID string or a MAC, and old rows may carry either.
    func testAddressMatchingIsCaseInsensitive() {
        XCTAssertEqual(SourceIdentity.resolve(address: "aa:bb:cc:dd:ee:02",
                                              rows: [ring, strap], currentId: "oura-abc"), "whoop-123")
    }

    /// A blank address is a missing address, not a wildcard that matches a blank stored value.
    func testBlankAddressLeavesTheIdAlone() {
        let blank = row("whoop-blank", "WHOOP", "")
        XCTAssertNil(SourceIdentity.resolve(address: "", rows: [blank], currentId: "oura-abc"))
        XCTAssertNil(SourceIdentity.resolve(address: nil, rows: [blank], currentId: "oura-abc"))
        // Whitespace is blank on both platforms — Kotlin's `isNullOrBlank` set the contract.
        let spaces = row("whoop-spaces", "WHOOP", "   ")
        XCTAssertNil(SourceIdentity.resolve(address: "   ", rows: [spaces], currentId: "oura-abc"))
    }

    /// The legacy id is a WHOOP by id even though its brand was never guaranteed.
    func testLegacyRowCountsAsWhoop() {
        let legacy = row("my-whoop", "", "AA:BB:CC:DD:EE:03")
        XCTAssertEqual(SourceIdentity.resolve(address: "AA:BB:CC:DD:EE:03",
                                              rows: [legacy], currentId: "oura-abc"), "my-whoop")
    }

    // MARK: - Archived rows sharing the address (re-added strap)

    /// The field bug: the strap was re-added, leaving the seeded row ARCHIVED with the same peripheral id
    /// and listed first. The link belongs to the active row, never the archived one.
    func testArchivedRowSharingTheAddressNeverWins() {
        let old = row("my-whoop", "WHOOP", "94DB7BE0-70F4-9C60-779B-224029185E6A", .archived)
        let now = row("whoop-5AG0743027", "WHOOP", "94DB7BE0-70F4-9C60-779B-224029185E6A", .active)
        XCTAssertEqual(SourceIdentity.resolve(address: "94DB7BE0-70F4-9C60-779B-224029185E6A",
                                              rows: [old, now], currentId: "my-whoop"), "whoop-5AG0743027")
        // ...and once the id is already the active row's, nothing moves it back.
        XCTAssertNil(SourceIdentity.resolve(address: "94DB7BE0-70F4-9C60-779B-224029185E6A",
                                            rows: [old, now], currentId: "whoop-5AG0743027"))
    }

    /// Only an archived row carries the address: leave the id alone, exactly as for no match.
    func testOnlyAnArchivedMatchLeavesTheIdAlone() {
        let old = row("whoop-old", "WHOOP", "AA:BB:CC:DD:EE:09", .archived)
        XCTAssertNil(SourceIdentity.resolve(address: "AA:BB:CC:DD:EE:09", rows: [old], currentId: "my-whoop"))
    }

    /// Two live rows share the address: the active one wins over a merely paired one.
    func testActiveRowWinsOverAPairedRowSharingTheAddress() {
        let paired = row("whoop-a", "WHOOP", "AA:BB:CC:DD:EE:0A", .paired)
        let active = row("whoop-b", "WHOOP", "AA:BB:CC:DD:EE:0A", .active)
        XCTAssertEqual(SourceIdentity.resolve(address: "AA:BB:CC:DD:EE:0A",
                                              rows: [paired, active], currentId: "x"), "whoop-b")
    }
}
