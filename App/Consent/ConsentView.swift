import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var flow: AppFlow
    @State private var hasReadTerms = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityHidden(true)
                    Text("Before we start")
                        .font(.system(.largeTitle, design: .serif).bold())
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Your health data deserves an explicit yes.")
                        .font(.callout)
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 14) {
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

                Toggle(isOn: $hasReadTerms) {
                    Text("I have read and understood the above")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Theme.ink)
                }
                .tint(Theme.primary)
                .card()

                Button {
                    flow.consentStore.accept()
                    flow.step = .intake
                } label: {
                    Text("Agree and continue")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!hasReadTerms)
                .accessibilityHint("Grants camera and data consent, then starts the intake questions")
            }
            .padding(20)
        }
        .themedScreen()
        .navigationTitle("Consent")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func consentPoint(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 40, height: 40)
                .background(Theme.primary.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
    }
}
