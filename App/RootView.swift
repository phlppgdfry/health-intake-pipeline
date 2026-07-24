import SwiftUI

struct RootView: View {
    @EnvironmentObject private var flow: AppFlow

    var body: some View {
        NavigationStack {
            Group {
                switch flow.step {
                case .consent:
                    ConsentView()
                case .intake:
                    IntakeView()
                case .scan:
                    CameraScanView()
                case .advice:
                    AdviceView()
                }
            }
            .toolbar {
                if flow.step != .consent {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Revoke consent", role: .destructive) {
                            flow.revokeConsent()
                        }
                        .font(.footnote)
                        .tint(Theme.primaryDeep)
                        .accessibilityHint("Deletes your answers and capture, and returns to the consent screen")
                    }
                }
            }
            .toolbarBackground(Theme.canvas, for: .navigationBar)
        }
    }
}
