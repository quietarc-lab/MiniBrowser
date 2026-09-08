import SwiftUI

struct SitePostStatusView: View {
    let status: SitePostStatus?

    var body: some View {
        Text(status?.rawValue ?? "")
            .font(.callout.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .frame(width: 96, height: 28)
            .background(backgroundColor, in: Capsule())
            .shadow(radius: 2)
            .opacity(status == nil ? 0 : 1)
            .accessibilityLabel(status?.rawValue ?? "")
            .allowsHitTesting(false)
    }

    private var backgroundColor: Color {
        switch status {
        case .sending: return .yellow
        case .completed: return .green
        case nil: return .clear
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .completed: return .white
        case .sending, nil: return .black
        }
    }
}
