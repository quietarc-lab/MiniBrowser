import Foundation

struct BrowserUserAgent: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let value: String

    static let all: [BrowserUserAgent] = [
        .init(id: 1,
              name: "Safari iPhone",
              value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"),
        .init(id: 2,
              name: "Chrome iPhone",
              value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1"),
        .init(id: 3,
              name: "Firefox iPhone",
              value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/143.0 Mobile/15E148 Safari/605.1.15"),
        .init(id: 4,
              name: "Edge iPhone",
              value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/140.0 Mobile/15E148 Safari/605.1.15"),
        .init(id: 5,
              name: "Brave iPhone",
              value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Mobile/15E148 Safari/604.1 Brave"),
        .init(id: 6,
              name: "DuckDuckGo iPhone",
              value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 DuckDuckGo/7 Safari/605.1.15"),
        .init(id: 7,
              name: "Opera iPhone",
              value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) OPiOS/6.1.0.11209 Mobile/15E148 Safari/9537.53"),
        .init(id: 8,
              name: "Safari iPad",
              value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"),
        .init(id: 9,
              name: "Chrome iPad",
              value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 Mobile/15E148 Safari/604.1"),
        .init(id: 10,
              name: "Firefox iPad",
              value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/143.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 11,
                name: "Safari iPhone 25.4",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/25.4 Mobile/15E148 Safari/604.1")
        , .init(id: 12,
                name: "Safari iPhone 25.5",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/25.5 Mobile/15E148 Safari/604.1")
        , .init(id: 13,
                name: "Safari iPhone 25.6",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/25.6 Mobile/15E148 Safari/604.1")
        , .init(id: 14,
                name: "Safari iPhone 26.1",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Mobile/15E148 Safari/604.1")
        , .init(id: 15,
                name: "Safari iPhone 26.2",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Mobile/15E148 Safari/604.1")
        , .init(id: 16,
                name: "Chrome iPhone 139",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/139.0.7258.76 Mobile/15E148 Safari/604.1")
        , .init(id: 17,
                name: "Chrome iPhone 138",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/138.0.7204.157 Mobile/15E148 Safari/604.1")
        , .init(id: 18,
                name: "Chrome iPhone 137",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/137.0.7151.107 Mobile/15E148 Safari/604.1")
        , .init(id: 19,
                name: "Chrome iPhone 136",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/136.0.7103.90 Mobile/15E148 Safari/604.1")
        , .init(id: 20,
                name: "Chrome iPhone 135",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/135.0.7049.84 Mobile/15E148 Safari/604.1")
        , .init(id: 21,
                name: "Firefox iPhone 142",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/142.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 22,
                name: "Firefox iPhone 141",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/141.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 23,
                name: "Firefox iPhone 140",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/140.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 24,
                name: "Firefox iPhone 139",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/139.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 25,
                name: "Firefox iPhone 138",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/138.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 26,
                name: "Edge iPhone 139",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/139.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 27,
                name: "Edge iPhone 138",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/138.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 28,
                name: "Edge iPhone 137",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/137.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 29,
                name: "Edge iPhone 136",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/136.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 30,
                name: "Edge iPhone 135",
                value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/135.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 31,
                name: "Safari iPad 25.4",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/25.4 Mobile/15E148 Safari/604.1")
        , .init(id: 32,
                name: "Safari iPad 25.5",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/25.5 Mobile/15E148 Safari/604.1")
        , .init(id: 33,
                name: "Safari iPad 25.6",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/25.6 Mobile/15E148 Safari/604.1")
        , .init(id: 34,
                name: "Safari iPad 26.1",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Mobile/15E148 Safari/604.1")
        , .init(id: 35,
                name: "Safari iPad 26.2",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.2 Mobile/15E148 Safari/604.1")
        , .init(id: 36,
                name: "Chrome iPad 139",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/139.0.7258.76 Mobile/15E148 Safari/604.1")
        , .init(id: 37,
                name: "Chrome iPad 138",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/138.0.7204.157 Mobile/15E148 Safari/604.1")
        , .init(id: 38,
                name: "Chrome iPad 137",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/137.0.7151.107 Mobile/15E148 Safari/604.1")
        , .init(id: 39,
                name: "Chrome iPad 136",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/136.0.7103.90 Mobile/15E148 Safari/604.1")
        , .init(id: 40,
                name: "Chrome iPad 135",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/135.0.7049.84 Mobile/15E148 Safari/604.1")
        , .init(id: 41,
                name: "Firefox iPad 142",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/142.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 42,
                name: "Firefox iPad 141",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/141.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 43,
                name: "Firefox iPad 140",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/140.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 44,
                name: "Firefox iPad 139",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/139.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 45,
                name: "Firefox iPad 138",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/138.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 46,
                name: "Edge iPad 139",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/139.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 47,
                name: "Edge iPad 138",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/138.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 48,
                name: "Edge iPad 137",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/137.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 49,
                name: "Edge iPad 136",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/136.0 Mobile/15E148 Safari/605.1.15")
        , .init(id: 50,
                name: "Edge iPad 135",
                value: "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EdgiOS/135.0 Mobile/15E148 Safari/605.1.15")
    ]
}
