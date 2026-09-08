import XCTest
@testable import MiniBrowser

final class AutomaticPostFlowTests: XCTestCase {
    private let generation: UInt64 = 42

    func testPreparationSchedulesOneInitialSubmitAfterAllSignals() {
        var machine = AutomaticPostFlowMachine()
        XCTAssertEqual(machine.begin(generationID: generation,
                                     oldPageToken: "old",
                                     hasComment: true,
                                     hasImage: false), .none)

        XCTAssertEqual(machine.handle(.markAPCompleted(generationID: generation)), .none)
        XCTAssertEqual(machine.handle(.markReloadCompleted(generationID: generation)), .none)
        XCTAssertEqual(machine.handle(.markCookieObserved(generationID: generation)), .none)
        XCTAssertEqual(machine.handle(.markCompactReady(generationID: generation,
                                                         pageToken: "new",
                                                         hasComment: true,
                                                         canSubmit: true)),
                       .scheduleInitialSubmit)
        XCTAssertEqual(machine.handle(.initialSubmitDelayElapsed(generationID: generation)),
                       .submit(attempt: 1))
        XCTAssertEqual(machine.state,
                       .submitting(generationID: generation, attempt: 1))
    }

    func testCookieAlertRetriesOnceWithoutConsumingIPBranch() {
        var machine = readyMachine(hasComment: true, hasImage: false)
        XCTAssertEqual(machine.handleAlert(.cookieRetryRequired, generationID: generation).autoDismiss,
                       true)
        XCTAssertEqual(machine.state,
                       .waitingForCookieRetry(generationID: generation, attempt: 1))
        XCTAssertEqual(machine.handle(.cookieAlertDismissed(generationID: generation)),
                       .submit(attempt: 2))

        XCTAssertEqual(machine.handleAlert(.cookieRetryRequired, generationID: generation).effect,
                       .stopped(.knownAlertAfterLimit))
        XCTAssertEqual(machine.state,
                       .stopped(generationID: generation, reason: .knownAlertAfterLimit))
    }

    func testIPAlertUsesAPOnlyAndMakesNextAttemptTerminal() {
        var machine = readyMachine(hasComment: true, hasImage: false)
        XCTAssertEqual(machine.handleAlert(.imagePostingRestricted,
                                           generationID: generation).effect,
                       .startIPReconnect)
        XCTAssertTrue(machine.ipRetryUsed)
        XCTAssertTrue(machine.ipRetryIsTerminal)
        XCTAssertEqual(machine.handle(.ipReconnectCompleted(generationID: generation,
                                                             success: true)), .none)
        XCTAssertEqual(machine.handle(.ipSubmitDelayElapsed(generationID: generation)),
                       .submit(attempt: 2))
        XCTAssertEqual(machine.handleAlert(.imagePostingRestricted,
                                           generationID: generation).effect,
                       .stopped(.knownAlertAfterLimit))
    }

    func testCookieThenIPUsesTheThirdAttempt() {
        var machine = readyMachine(hasComment: true, hasImage: false)
        _ = machine.handleAlert(.cookieRetryRequired, generationID: generation)
        XCTAssertEqual(machine.handle(.cookieAlertDismissed(generationID: generation)),
                       .submit(attempt: 2))
        XCTAssertEqual(machine.handleAlert(.imagePostingRestricted,
                                           generationID: generation).effect,
                       .startIPReconnect)
        XCTAssertEqual(machine.handle(.ipReconnectCompleted(generationID: generation,
                                                             success: true)), .none)
        XCTAssertEqual(machine.handle(.ipSubmitDelayElapsed(generationID: generation)),
                       .submit(attempt: 3))
    }

    func testCompletionAndFailuresStopFurtherEvents() {
        var machine = readyMachine(hasComment: true, hasImage: false)
        XCTAssertEqual(machine.handle(.postCompleted(generationID: generation)), .succeeded)
        XCTAssertEqual(machine.handleAlert(.cookieRetryRequired, generationID: generation).autoDismiss,
                       false)

        machine = readyMachine(hasComment: true, hasImage: false)
        XCTAssertEqual(machine.handle(.fail(generationID: generation,
                                             reason: .preparationTimeout)),
                       .stopped(.preparationTimeout))
        XCTAssertEqual(machine.handle(.postCompleted(generationID: generation)), .none)
    }

    func testStaleGenerationAndOldPageTokenAreIgnored() {
        var machine = AutomaticPostFlowMachine()
        _ = machine.begin(generationID: generation,
                          oldPageToken: "same-page-before-reload",
                          hasComment: true,
                          hasImage: false)
        XCTAssertEqual(machine.handle(.markCompactReady(generationID: generation,
                                                         pageToken: "same-page-before-reload",
                                                         hasComment: true,
                                                         canSubmit: true)), .none)
        XCTAssertEqual(machine.handle(.markCompactReady(generationID: generation + 1,
                                                         pageToken: "new",
                                                         hasComment: true,
                                                         canSubmit: true)), .none)
        XCTAssertEqual(machine.pageToken, nil)
        XCTAssertTrue(machine.isStalePageToken("same-page-before-reload"))
        XCTAssertEqual(machine.handle(.markCompactReady(generationID: generation,
                                                         pageToken: "new",
                                                         hasComment: true,
                                                         canSubmit: true)), .none)
        XCTAssertEqual(machine.pageToken, "new")
    }

    func testImagePreparationRequiresHandwritingReady() {
        var machine = AutomaticPostFlowMachine()
        _ = machine.begin(generationID: generation,
                          oldPageToken: nil,
                          hasComment: false,
                          hasImage: true)
        _ = machine.handle(.markAPCompleted(generationID: generation))
        _ = machine.handle(.markReloadCompleted(generationID: generation))
        _ = machine.handle(.markCookieObserved(generationID: generation))
        XCTAssertEqual(machine.handle(.markCompactReady(generationID: generation,
                                                         pageToken: "page",
                                                         hasComment: false,
                                                         canSubmit: true)), .none)
        XCTAssertEqual(machine.handle(.markHandwritingReady(generationID: generation,
                                                             pageToken: "page",
                                                             ready: true)),
                       .scheduleInitialSubmit)
    }

    func testEmptyCandidateStopsWithoutSubmitting() {
        var machine = AutomaticPostFlowMachine()
        XCTAssertEqual(machine.begin(generationID: generation,
                                     oldPageToken: nil,
                                     hasComment: false,
                                     hasImage: false),
                       .stopped(.noContent))
        XCTAssertFalse(machine.isActive)
    }

    private func readyMachine(hasComment: Bool, hasImage: Bool) -> AutomaticPostFlowMachine {
        var machine = AutomaticPostFlowMachine()
        _ = machine.begin(generationID: generation,
                          oldPageToken: nil,
                          hasComment: hasComment,
                          hasImage: hasImage)
        _ = machine.handle(.markAPCompleted(generationID: generation))
        _ = machine.handle(.markReloadCompleted(generationID: generation))
        _ = machine.handle(.markCookieObserved(generationID: generation))
        _ = machine.handle(.markCompactReady(generationID: generation,
                                              pageToken: "page",
                                              hasComment: hasComment,
                                              canSubmit: true))
        if hasImage {
            _ = machine.handle(.markHandwritingReady(generationID: generation,
                                                      pageToken: "page",
                                                      ready: true))
        }
        _ = machine.handle(.initialSubmitDelayElapsed(generationID: generation))
        return machine
    }
}
