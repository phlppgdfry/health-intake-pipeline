import Foundation

/// Consent is explicit, versioned and revocable.
///
/// Versioned: if the consent text materially changes, bump `currentVersion`
/// and every user is asked again — silently carrying over old consent to new
/// terms is not acceptable for health data.
final class ConsentStore {
    static let currentVersion = 1
    private let defaults: UserDefaults
    private let key = "consent.acceptedVersion"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasConsent: Bool {
        defaults.integer(forKey: key) == Self.currentVersion
    }

    func accept() {
        defaults.set(Self.currentVersion, forKey: key)
    }

    func revoke() {
        defaults.removeObject(forKey: key)
    }
}
