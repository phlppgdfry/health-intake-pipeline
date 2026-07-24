import SwiftUI

struct IntakeView: View {
    @EnvironmentObject private var flow: AppFlow
    @StateObject private var model = IntakeViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Question \(model.index + 1) of \(model.questions.count)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                    .textCase(.uppercase)
                ProgressView(value: model.progress)
                    .tint(Theme.primary)
                    .accessibilityLabel("Intake progress")
                    .accessibilityValue("\(model.answers.count) of \(model.questions.count) questions answered")
            }

            Text(model.current.text)
                .font(.system(.title, design: .serif).bold())
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 12) {
                ForEach(model.current.options, id: \.self) { option in
                    optionRow(option)
                }
            }
            .animation(.snappy(duration: 0.25), value: model.index)

            Spacer()

            if model.index > 0 {
                Button {
                    model.goBack()
                } label: {
                    Label("Previous question", systemImage: "chevron.left")
                        .font(.callout.weight(.medium))
                }
                .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(20)
        .themedScreen()
        .navigationTitle("Intake")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionRow(_ option: String) -> some View {
        let isSelected = model.selectedAnswer(for: model.current) == option
        return Button {
            model.answer(option)
            if model.isComplete {
                flow.intakeAnswers = model.answers
                flow.step = .scan
            }
        } label: {
            HStack {
                Text(option)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.primary : Theme.inkSoft.opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Theme.primary : Theme.ink.opacity(0.08),
                                  lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: Theme.ink.opacity(0.05), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
