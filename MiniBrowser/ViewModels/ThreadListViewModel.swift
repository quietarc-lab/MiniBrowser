import Combine
import Foundation

@MainActor
final class ThreadListViewModel: ObservableObject {
    private static let listItemLimit = 60
    private enum Keys {
        static let sort = "ThreadListSort"
        static let expanded = "ThreadListExpanded"
        static let openCounts = "ThreadListOpenCounts"
    }

    @Published private(set) var items: [ThreadListItem] = []
    @Published private(set) var selectedSort: ThreadListSort
    @Published private(set) var isExpanded: Bool
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var openCounts: [String: Int]

    private let service: ThreadListService
    private let defaults: UserDefaults
    private var isSceneActive = true
    private var isNetworkActivityAllowed = true
    private var userAgent = BrowserUserAgent.all[0].value
    private var hasStarted = false
    private var loadTask: Task<Void, Never>?
    private var refreshLoopTask: Task<Void, Never>?
    // A slow/failed request must not permanently starve cells later in the
    // grid: the next automatic refresh starts after the last attempted cell.
    private var nextThumbnailRetryID: String?

    init(service: ThreadListService = ThreadListService(),
         defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        self.selectedSort = ThreadListSort(
            rawValue: defaults.string(forKey: Keys.sort) ?? ""
        ) ?? .momentum
        self.isExpanded = defaults.object(forKey: Keys.expanded) == nil
            ? true
            : defaults.bool(forKey: Keys.expanded)
        self.openCounts = defaults.dictionary(forKey: Keys.openCounts)?
            .compactMapValues { ($0 as? NSNumber)?.intValue } ?? [:]
    }

    deinit {
        loadTask?.cancel()
        refreshLoopTask?.cancel()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        if isExpanded {
            refresh()
        }
        updateRefreshLoop()
    }

    func setSceneActive(_ active: Bool) {
        guard isSceneActive != active else { return }
        isSceneActive = active
        updateRefreshLoop()
    }

    func setNetworkActivityAllowed(_ allowed: Bool) {
        guard isNetworkActivityAllowed != allowed else { return }
        isNetworkActivityAllowed = allowed
        if !allowed {
            loadTask?.cancel()
            loadTask = nil
            isRefreshing = false
        } else if hasStarted, isExpanded {
            refresh()
        }
        updateRefreshLoop()
    }

    func setUserAgent(_ value: String) {
        userAgent = value
    }

    func toggleExpanded() {
        isExpanded.toggle()
        defaults.set(isExpanded, forKey: Keys.expanded)
        if isExpanded {
            refresh()
        } else {
            loadTask?.cancel()
            isRefreshing = false
        }
        updateRefreshLoop()
    }

    func selectSort(_ sort: ThreadListSort) {
        guard selectedSort != sort else { return }
        selectedSort = sort
        defaults.set(sort.rawValue, forKey: Keys.sort)
        refresh()
    }

    func refresh() {
        guard isExpanded, isSceneActive, isNetworkActivityAllowed else { return }
        loadTask?.cancel()
        let sort = selectedSort
        isRefreshing = true
        errorMessage = nil

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                await service.updateUserAgent(userAgent)
                let loaded = try await service.fetchList(sort: sort,
                                                            limit: Self.listItemLimit)
                try Task.checkCancellation()
                guard selectedSort == sort, isNetworkActivityAllowed else { return }
                items = Self.mergingDisplayState(of: loaded, with: items)
                isRefreshing = false
                await loadThumbnails(for: loaded, sort: sort)
                await loadOpenerTexts(for: loaded, sort: sort)
            } catch is CancellationError {
                isRefreshing = false
            } catch {
                isRefreshing = false
                errorMessage = "更新失敗"
            }
        }
    }

    func recordOpen(_ item: ThreadListItem) {
        openCounts[item.id, default: 0] += 1
        if openCounts.count > 1_000 {
            let excess = openCounts.count - 1_000
            let oldestIDs = openCounts.keys.sorted {
                (Int($0) ?? 0) < (Int($1) ?? 0)
            }.prefix(excess)
            for id in oldestIDs {
                openCounts.removeValue(forKey: id)
            }
        }
        defaults.set(openCounts, forKey: Keys.openCounts)
    }

    func openCount(for item: ThreadListItem) -> Int {
        openCounts[item.id, default: 0]
    }

    func resetOpenHistory() {
        openCounts = [:]
        defaults.removeObject(forKey: Keys.openCounts)
    }

    private func loadThumbnails(for loaded: [ThreadListItem],
                                sort: ThreadListSort) async {
        let unresolved = loaded.filter { item in
            items.first(where: { $0.id == item.id })?.thumbnailData == nil
        }
        let ordered = orderedForThumbnailRetry(unresolved)

        for (index, item) in ordered.enumerated() {
            guard !Task.isCancelled, selectedSort == sort else { return }
            advanceThumbnailRetry(after: index, in: ordered)
            do {
                let data = try await service.thumbnailData(for: item,
                                                           referer: sort.url)
                guard !Task.isCancelled, selectedSort == sort else { return }
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].thumbnailData = data
                    items[index].thumbnailLoadFailed = false
                }
            } catch is CancellationError {
                return
            } catch {
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].thumbnailLoadFailed = true
                }
            }
            await Task.yield()
        }
    }

    private func orderedForThumbnailRetry(_ unresolved: [ThreadListItem]) -> [ThreadListItem] {
        guard let nextThumbnailRetryID,
              let index = unresolved.firstIndex(where: { $0.id == nextThumbnailRetryID }) else {
            return unresolved
        }
        return Array(unresolved[index...]) + Array(unresolved[..<index])
    }

    private func advanceThumbnailRetry(after index: Int,
                                       in ordered: [ThreadListItem]) {
        guard !ordered.isEmpty else {
            nextThumbnailRetryID = nil
            return
        }
        nextThumbnailRetryID = ordered[(index + 1) % ordered.count].id
    }

    nonisolated static func mergingDisplayState(of loaded: [ThreadListItem],
                                                 with previous: [ThreadListItem]) -> [ThreadListItem] {
        let previousByID = previous.reduce(into: [String: ThreadListItem]()) { result, item in
            result[item.id] = item
        }
        return loaded.map { item in
            guard let oldItem = previousByID[item.id] else { return item }

            var merged = item
            // Keep a successfully fetched image while a 60-second refresh is
            // obtaining the new list. A changed thumbnail URL deliberately
            // starts fresh so it can be fetched again.
            if oldItem.thumbnailURL == item.thumbnailURL {
                merged.thumbnailData = oldItem.thumbnailData
                merged.thumbnailLoadFailed = oldItem.thumbnailLoadFailed
            }
            merged.openerText = oldItem.openerText
            return merged
        }
    }

    private func loadOpenerTexts(for loaded: [ThreadListItem],
                                 sort: ThreadListSort) async {
        for item in loaded {
            guard !Task.isCancelled, selectedSort == sort else { return }
            let text: String
            do {
                text = try await service.openerText(for: item)
            } catch is CancellationError {
                return
            } catch {
                text = "本文取得失敗"
            }

            guard !Task.isCancelled, selectedSort == sort else { return }
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].openerText = text
            }
            await Task.yield()
        }
    }

    private func updateRefreshLoop() {
        refreshLoopTask?.cancel()
        refreshLoopTask = nil
        guard hasStarted, isExpanded, isSceneActive, isNetworkActivityAllowed else { return }

        refreshLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    return
                }
                guard let self, self.isExpanded, self.isSceneActive,
                      self.isNetworkActivityAllowed else { return }
                self.refresh()
            }
        }
    }
}
