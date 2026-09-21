import Foundation
import UserNotifications

enum CompletionNotifications {
    enum Action: Equatable {
        case request, enable, none
    }

    static func action(preference: Bool?, authorization: UNAuthorizationStatus) -> Action {
        guard preference != false else { return .none }
        switch authorization {
        case .notDetermined: return .request
        case .authorized, .provisional, .ephemeral: return preference == nil ? .enable : .none
        default: return .none
        }
    }

    static func prepare() async {
        let defaults = UserDefaults.standard
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch action(preference: defaults.object(forKey: "verse.completionNotifications") as? Bool,
                      authorization: settings.authorizationStatus) {
        case .request:
            if let enabled = try? await center.requestAuthorization(options: [.alert, .sound]) {
                defaults.set(enabled, forKey: "verse.completionNotifications")
            }
        case .enable:
            defaults.set(true, forKey: "verse.completionNotifications")
        case .none:
            break
        }
    }
}
