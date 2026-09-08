import Foundation
import XCTest
@testable import MiniBrowser

@MainActor
final class ThreadListViewModelTests: XCTestCase {
    func testOpenCountUpdatesAndPersistsAcrossViewModels() {
        let suiteName = "ThreadListViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let item = ThreadListItem(
            id: "1234567890",
            threadURL: URL(string: "https://img.2chan.net/b/res/1234567890.htm")!,
            thumbnailURL: URL(string: "https://img.2chan.net/b/cat/123s.jpg")!,
            replyCount: 10,
            thumbnailData: nil,
            openerText: "本文"
        )

        let firstModel = ThreadListViewModel(defaults: defaults)
        XCTAssertEqual(firstModel.openCount(for: item), 0)
        firstModel.recordOpen(item)
        firstModel.recordOpen(item)
        XCTAssertEqual(firstModel.openCount(for: item), 2)

        let restoredModel = ThreadListViewModel(defaults: defaults)
        XCTAssertEqual(restoredModel.openCount(for: item), 2)
    }

    func testResetOpenHistoryClearsAndPersistsEmptyState() {
        let suiteName = "ThreadListViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let item = ThreadListItem(
            id: "9876543210",
            threadURL: URL(string: "https://img.2chan.net/b/res/9876543210.htm")!,
            thumbnailURL: URL(string: "https://img.2chan.net/b/cat/987s.jpg")!,
            replyCount: 10,
            thumbnailData: nil,
            openerText: "本文"
        )

        let model = ThreadListViewModel(defaults: defaults)
        model.recordOpen(item)
        model.recordOpen(item)
        XCTAssertEqual(model.openCount(for: item), 2)

        model.resetOpenHistory()

        XCTAssertTrue(model.openCounts.isEmpty)
        XCTAssertEqual(model.openCount(for: item), 0)
        let restoredModel = ThreadListViewModel(defaults: defaults)
        XCTAssertEqual(restoredModel.openCount(for: item), 0)
    }

    func testListRefreshPreservesMatchingThumbnailAndRetriesChangedImage() {
        let originalURL = URL(string: "https://img.2chan.net/b/cat/123s.jpg")!
        let item = ThreadListItem(
            id: "123",
            threadURL: URL(string: "https://img.2chan.net/b/res/123.htm")!,
            thumbnailURL: originalURL,
            replyCount: 5,
            thumbnailData: Data([1, 2, 3]),
            openerText: "以前の本文"
        )
        let unchanged = ThreadListItem(
            id: "123",
            threadURL: item.threadURL,
            thumbnailURL: originalURL,
            replyCount: 6,
            thumbnailData: nil,
            openerText: nil
        )
        let changedImage = ThreadListItem(
            id: "123",
            threadURL: item.threadURL,
            thumbnailURL: URL(string: "https://img.2chan.net/b/cat/123-new.jpg")!,
            replyCount: 7,
            thumbnailData: nil,
            openerText: nil
        )

        let retained = ThreadListViewModel.mergingDisplayState(of: [unchanged], with: [item])
        XCTAssertEqual(retained.first?.thumbnailData, Data([1, 2, 3]))
        XCTAssertEqual(retained.first?.openerText, "以前の本文")

        let refreshed = ThreadListViewModel.mergingDisplayState(of: [changedImage], with: [item])
        XCTAssertNil(refreshed.first?.thumbnailData)
        XCTAssertEqual(refreshed.first?.openerText, "以前の本文")
    }
}
