import AudioToolbox
import UIKit

/// Multi-sensory confirmation that the auto-capture fired: the user is
/// watching the subject, not the screen, so sound and haptics carry the
/// "got it" moment. The shutter sound is the system camera shutter, which
/// users already know means "photo taken".
@MainActor
enum CaptureFeedback {
    private static let shutterSoundID: SystemSoundID = 1108

    static func play() {
        AudioServicesPlaySystemSound(shutterSoundID)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
