import Foundation

enum AutomaticPostAlert: Equatable {
    case cookieRetryRequired
    case imagePostingRestricted
}

enum TargetPageAlertDisposition: Equatable {
    case showNormally
    case autoDismiss
}

enum AutomaticPostStopReason: Equatable {
    case noContent
    case preparationTimeout
    case preparationFailed
    case communicationFailure
    case unknownAlert
    case knownAlertAfterLimit
    case retryLimit
}

enum AutomaticPostFlowState: Equatable {
    case idle
    case preparing(generationID: UInt64)
    case waitingToSubmit(generationID: UInt64, attempt: Int)
    case submitting(generationID: UInt64, attempt: Int)
    case waitingForCookieRetry(generationID: UInt64, attempt: Int)
    case waitingForIPRetry(generationID: UInt64, attempt: Int)
    case succeeded(generationID: UInt64)
    case stopped(generationID: UInt64, reason: AutomaticPostStopReason)
}

enum AutomaticPostFlowEffect: Equatable {
    case none
    case scheduleInitialSubmit
    case submit(attempt: Int)
    case startIPReconnect
    case succeeded
    case stopped(AutomaticPostStopReason)
}

enum AutomaticPostFlowEvent: Equatable {
    case markAPCompleted(generationID: UInt64)
    case markReloadCompleted(generationID: UInt64)
    case markCookieObserved(generationID: UInt64)
    case markCompactReady(generationID: UInt64,
                          pageToken: String,
                          hasComment: Bool,
                          canSubmit: Bool)
    case markHandwritingReady(generationID: UInt64,
                              pageToken: String,
                              ready: Bool)
    case initialSubmitDelayElapsed(generationID: UInt64)
    case cookieAlertDismissed(generationID: UInt64)
    case ipReconnectCompleted(generationID: UInt64, success: Bool)
    case ipSubmitDelayElapsed(generationID: UInt64)
    case postCompleted(generationID: UInt64)
    case fail(generationID: UInt64, reason: AutomaticPostStopReason)
    case reset
}

struct AutomaticPostFlowMachine {
    static let maximumAttempts = 3

    private(set) var state: AutomaticPostFlowState = .idle
    private(set) var generationID: UInt64?
    private(set) var pageToken: String?
    private(set) var cookieRetryUsed = false
    private(set) var ipRetryUsed = false
    private(set) var ipRetryIsTerminal = false
    private(set) var requiresHandwriting = false
    private(set) var lastAttempt = 0

    private var stalePageToken: String?
    private var apCompleted = false
    private var reloadCompleted = false
    private var cookieObserved = false
    private var compactReady = false
    private var handwritingReady = false
    private var ipReconnectCompleted = false

    var isActive: Bool {
        switch state {
        case .preparing, .waitingToSubmit, .submitting,
             .waitingForCookieRetry, .waitingForIPRetry:
            return true
        case .idle, .succeeded, .stopped:
            return false
        }
    }

    var currentAttempt: Int? {
        switch state {
        case let .waitingToSubmit(_, attempt),
             let .submitting(_, attempt),
             let .waitingForCookieRetry(_, attempt),
             let .waitingForIPRetry(_, attempt):
            return attempt
        case .idle, .preparing, .succeeded, .stopped:
            return nil
        }
    }

    func isStalePageToken(_ token: String) -> Bool {
        guard let stalePageToken,
              pageToken == nil else { return false }
        return stalePageToken == token
    }

    mutating func begin(generationID: UInt64,
                        oldPageToken: String?,
                        hasComment: Bool,
                        hasImage: Bool) -> AutomaticPostFlowEffect {
        guard hasComment || hasImage else {
            state = .stopped(generationID: generationID, reason: .noContent)
            self.generationID = generationID
            return .stopped(.noContent)
        }

        self.generationID = generationID
        stalePageToken = oldPageToken
        pageToken = nil
        requiresHandwriting = hasImage
        cookieRetryUsed = false
        ipRetryUsed = false
        ipRetryIsTerminal = false
        lastAttempt = 0
        apCompleted = false
        reloadCompleted = false
        cookieObserved = false
        compactReady = false
        handwritingReady = !hasImage
        ipReconnectCompleted = false
        state = .preparing(generationID: generationID)
        return .none
    }

    mutating func handle(_ event: AutomaticPostFlowEvent) -> AutomaticPostFlowEffect {
        if case .reset = event {
            reset()
            return .none
        }

        guard let eventGenerationID = event.generationID,
              eventGenerationID == generationID else {
            return .none
        }

        switch event {
        case .reset:
            return .none

        case .markAPCompleted:
            guard case .preparing = state else { return .none }
            apCompleted = true
            return preparationEffectIfReady()

        case .markReloadCompleted:
            guard case .preparing = state else { return .none }
            reloadCompleted = true
            return preparationEffectIfReady()

        case .markCookieObserved:
            guard case .preparing = state else { return .none }
            cookieObserved = true
            return preparationEffectIfReady()

        case let .markCompactReady(_, token, hasComment, canSubmit):
            guard case .preparing = state,
                  acceptPageToken(token) else {
                return .none
            }
            guard hasComment || requiresHandwriting else {
                return stop(.noContent)
            }
            guard canSubmit else {
                return stop(.preparationFailed)
            }
            compactReady = true
            return preparationEffectIfReady()

        case let .markHandwritingReady(_, token, ready):
            guard case .preparing = state,
                  acceptPageToken(token) else {
                return .none
            }
            guard ready else {
                return stop(.preparationFailed)
            }
            handwritingReady = true
            return preparationEffectIfReady()

        case .initialSubmitDelayElapsed:
            guard case let .waitingToSubmit(_, attempt) = state,
                  attempt == 1 else { return .none }
            return beginSubmit(attempt: attempt)

        case .cookieAlertDismissed:
            guard case let .waitingForCookieRetry(_, attempt) = state,
                  attempt < Self.maximumAttempts else {
                return .none
            }
            return beginSubmit(attempt: attempt + 1)

        case let .ipReconnectCompleted(_, success):
            guard case .waitingForIPRetry = state else { return .none }
            guard success else {
                return stop(.communicationFailure)
            }
            ipReconnectCompleted = true
            return .none

        case .ipSubmitDelayElapsed:
            guard case let .waitingForIPRetry(_, attempt) = state,
                  ipReconnectCompleted,
                  attempt < Self.maximumAttempts else {
                return .none
            }
            return beginSubmit(attempt: attempt + 1)

        case .postCompleted:
            guard case .submitting = state else { return .none }
            state = .succeeded(generationID: eventGenerationID)
            return .succeeded

        case let .fail(_, reason):
            return stop(reason)
        }
    }

    mutating func handleAlert(_ alert: AutomaticPostAlert,
                              generationID: UInt64) -> (autoDismiss: Bool,
                                                       effect: AutomaticPostFlowEffect) {
        guard generationID == self.generationID,
              case let .submitting(_, attempt) = state else {
            return (false, .none)
        }

        switch alert {
        case .cookieRetryRequired:
            guard !cookieRetryUsed,
                  !ipRetryIsTerminal,
                  attempt < Self.maximumAttempts else {
                return (true, stop(.knownAlertAfterLimit))
            }
            cookieRetryUsed = true
            state = .waitingForCookieRetry(generationID: generationID, attempt: attempt)
            return (true, .none)

        case .imagePostingRestricted:
            guard !ipRetryUsed,
                  attempt < Self.maximumAttempts else {
                return (true, stop(.knownAlertAfterLimit))
            }
            ipRetryUsed = true
            ipRetryIsTerminal = true
            ipReconnectCompleted = false
            state = .waitingForIPRetry(generationID: generationID, attempt: attempt)
            return (true, .startIPReconnect)
        }
    }

    mutating func stop(_ reason: AutomaticPostStopReason) -> AutomaticPostFlowEffect {
        guard let generationID else { return .none }
        state = .stopped(generationID: generationID, reason: reason)
        return .stopped(reason)
    }

    mutating func reset() {
        state = .idle
        generationID = nil
        pageToken = nil
        stalePageToken = nil
        cookieRetryUsed = false
        ipRetryUsed = false
        ipRetryIsTerminal = false
        requiresHandwriting = false
        lastAttempt = 0
        apCompleted = false
        reloadCompleted = false
        cookieObserved = false
        compactReady = false
        handwritingReady = false
        ipReconnectCompleted = false
    }

    private mutating func preparationEffectIfReady() -> AutomaticPostFlowEffect {
        guard case .preparing = state,
              apCompleted,
              reloadCompleted,
              cookieObserved,
              compactReady,
              handwritingReady else {
            return .none
        }
        state = .waitingToSubmit(generationID: generationID ?? 0, attempt: 1)
        lastAttempt = 1
        return .scheduleInitialSubmit
    }

    private mutating func beginSubmit(attempt: Int) -> AutomaticPostFlowEffect {
        guard attempt <= Self.maximumAttempts,
              let generationID else {
            return stop(.retryLimit)
        }
        state = .submitting(generationID: generationID, attempt: attempt)
        lastAttempt = attempt
        return .submit(attempt: attempt)
    }

    private mutating func acceptPageToken(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        if let pageToken {
            return pageToken == token
        }
        if stalePageToken == token {
            return false
        }
        pageToken = token
        return true
    }
}

private extension AutomaticPostFlowEvent {
    var generationID: UInt64? {
        switch self {
        case .reset:
            return nil
        case let .markAPCompleted(id),
             let .markReloadCompleted(id),
             let .markCookieObserved(id),
             let .initialSubmitDelayElapsed(id),
             let .cookieAlertDismissed(id),
             let .ipSubmitDelayElapsed(id),
             let .postCompleted(id),
             let .fail(id, _):
            return id
        case let .markCompactReady(id, _, _, _),
             let .markHandwritingReady(id, _, _),
             let .ipReconnectCompleted(id, _):
            return id
        }
    }
}
