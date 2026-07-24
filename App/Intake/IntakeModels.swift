import Foundation

struct IntakeQuestion: Identifiable, Equatable {
    let id: String
    let text: String
    let options: [String]

    /// A deliberately small, non-clinical demo questionnaire. In a real
    /// product this catalog would come from the engine and be clinically owned.
    static let demoCatalog: [IntakeQuestion] = [
        .init(id: "reason",
              text: "What brings you here today?",
              options: ["Skin concern", "Energy & sleep", "Digestion", "General check"]),
        .init(id: "duration",
              text: "How long have you had this concern?",
              options: ["Less than a week", "A few weeks", "Months", "Years"]),
        .init(id: "impact",
              text: "How much does it affect your daily life?",
              options: ["Barely", "Somewhat", "A lot"]),
    ]
}

struct IntakeAnswer: Equatable, Codable {
    let questionID: String
    let answer: String
}
