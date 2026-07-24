import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var flow: AppFlow
    @State private var hasReadTerms = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label("Before we start", systemImage: "hand.raised.fill")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 16) {
                    consentPoint(icon: "camera.fill",
                                 title: "Camera",
                                 text: "The camera captures one scan that becomes input for your advice. Nothing is recorded until you see the capture screen.")
                    consentPoint(icon: "iphone.and.arrow.forward",
                                 title: "Your data stays on this device",
                                 text: "Answers and scans are stored encrypted on your device only. In this demo nothing is uploaded.")
                    consentPoint(icon: "trash.fill",
                                 title: "Revocable at any time",
                                 text: "Revoking consent deletes your answers and captures immediately.")
                }

                Toggle("I have read and understood the above", isOn: $hasReadTerms)
                    .font(.callout)

                Button {
                    flow.consentStore.accept()
                    flow.step = .intake
                } label: {
                    Text("Agree and continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!hasReadTerms)
                .accessibilityHint("Grants camera and data consent, then starts the intake questions")
            }
            .padding()
        }
        .navigationTitle("Consent")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func consentPoint(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
