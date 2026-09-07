import XCTest
@testable import MiniBrowser

final class CompactPageModeServiceTests: XCTestCase {
    func testScriptIsRestrictedToImgThreadPages() {
        let script = CompactPageModeService.scriptSource
        XCTAssertTrue(script.contains("location.hostname !== \"img.2chan.net\""))
        XCTAssertTrue(script.contains(#"\/res\/"#))
    }

    func testScriptIncludesRequestedFocusModeBehavior() {
        let script = CompactPageModeService.scriptSource
        XCTAssertTrue(script.contains("width=device-width, initial-scale=1"))
        XCTAssertTrue(script.contains(".minibrowser-targetpage-form .ftb2"))
        XCTAssertTrue(script.contains("minibrowser-targetpage-starter"))
        XCTAssertTrue(script.contains("minibrowser-targetpage-context"))
        XCTAssertTrue(script.contains("minibrowser-targetpage-opener"))
        XCTAssertTrue(script.contains("-webkit-line-clamp: 4"))
        XCTAssertTrue(script.contains("本文なし"))
        XCTAssertTrue(script.contains("minibrowser-targetpage-page-extra"))
        XCTAssertTrue(script.contains("#contres"))
        XCTAssertTrue(script.contains("#ufm"))
        XCTAssertTrue(script.contains("minibrowser-own-response"))
        XCTAssertTrue(script.contains("MiniBrowser.TargetPageOwnPosts:"))
        XCTAssertTrue(script.contains("10 * 60 * 1000"),
                      "Unmatched post bodies must expire instead of remaining indefinitely.")
        XCTAssertTrue(script.contains("minibrowser-targetpage-email-row"))
        XCTAssertTrue(script.contains("clearEmail"))
        XCTAssertTrue(script.contains("textarea.rows = 2"))
        XCTAssertTrue(script.contains("minibrowser-targetpage-delete-help"))
        XCTAssertTrue(script.contains("disableFormPositionToggle"))
        XCTAssertTrue(script.contains("preserveDeleteKey"))
        XCTAssertFalse(script.contains("deleteInput.readOnly = true"))
        XCTAssertFalse(script.contains("fixedDeleteKey"))
        XCTAssertTrue(script.contains("minibrowser-targetpage-comment-actions"))
        XCTAssertTrue(script.contains("modeHeader.classList.add(\"minibrowser-targetpage-page-extra\")"))
        XCTAssertTrue(script.contains("form.insertBefore(actions, formTable || form.firstChild)"))
        XCTAssertTrue(script.contains("#retmestip"))
        XCTAssertFalse(script.contains("minibrowser-targetpage-submit-status"))
        XCTAssertTrue(script.contains("localStorage.removeItem(\"MiniBrowser.TargetPageFormPlacement\")"))
        XCTAssertFalse(script.contains("latestOwnResponse.table.after(form)"))
        XCTAssertTrue(script.contains("initializeCompactPage"))
        XCTAssertTrue(script.contains("minibrowserCompactInitialized"))
        XCTAssertTrue(script.contains("retryCount >= 20"))
    }

    func testScriptIncludesGlobalDraftRetentionControls() {
        let script = CompactPageModeService.scriptSource
        XCTAssertTrue(script.contains("MiniBrowser.TargetPageDraftEnabled"))
        XCTAssertTrue(script.contains("MiniBrowser.TargetPageDraftText"))
        XCTAssertTrue(script.contains("保持 ON"))
        XCTAssertTrue(script.contains("保持 OFF"))
        XCTAssertTrue(script.contains("localStorage.removeItem(draftTextKey)"))
        XCTAssertTrue(script.contains("capturePostState"))
        XCTAssertTrue(script.contains("submitButton.addEventListener(\"click\", capturePostState, true)"))
        XCTAssertTrue(script.contains("restoreSubmittedDraft"))
        XCTAssertTrue(script.contains("userEditedAfterSubmission"))
        XCTAssertTrue(script.contains("type: \"postCompleted\""))
    }
}
