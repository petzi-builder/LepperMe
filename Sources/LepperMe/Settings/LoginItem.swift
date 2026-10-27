import Foundation
import ServiceManagement

/// "Bei Anmeldung starten" via SMAppService. Only works when running from a real .app bundle.
enum LoginItem {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LepperMe: Login item could not be \(enabled ? "registered" : "unregistered"): \(error)")
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
