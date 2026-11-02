import AppKit
import CoreFoundation

// Runs as a temporary .app with its own bundle identifier; never touches the
// daily installation's defaults or macOS privacy grants.
MainActor.assumeIsolated {
    _ = NSApplication.shared
    let domain = Bundle.main.bundleIdentifier!
    precondition(domain.hasPrefix("org.hairpin.update-test."))
    precondition(Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String == "https://github.com/HiAriesZhou/Hairpin/releases/latest/download/appcast.xml")
    for key in ["SURequireSignedFeed", "SUVerifyUpdateBeforeExtraction", "SUEnableAutomaticChecks"] {
        precondition(Bundle.main.object(forInfoDictionaryKey: key) as? Bool == true, key)
    }
    for key in ["SUAutomaticallyUpdate", "SUEnableSystemProfiling", "SUEnableJavaScript"] {
        precondition(Bundle.main.object(forInfoDictionaryKey: key) as? Bool == false, key)
    }
    precondition(Bundle.main.object(forInfoDictionaryKey: "SUScheduledCheckInterval") as? Int == 86400)
    // An old or externally changed preference must not override the privacy policy.
    UserDefaults.standard.set(true, forKey: "SUSendProfileInfo")
    let updates = Updates()
    precondition(!UserDefaults.standard.bool(forKey: "SUSendProfileInfo"))
    if CommandLine.arguments.contains("persisted") {
        precondition(updates.automaticallyChecks && updates.automaticallyInstalls)
        updates.automaticallyChecks = false
        precondition(!updates.automaticallyInstalls)
        CFPreferencesAppSynchronize(domain as CFString)
        print("Automatic update opt-in persisted across processes")
    } else if CommandLine.arguments.contains("disabled") {
        precondition(!updates.automaticallyChecks)
        precondition(!updates.automaticallyInstalls)
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        print("Update preferences persisted across processes")
    } else {
        precondition(updates.automaticallyChecks, "Fresh installs must check by default")
        precondition(!updates.automaticallyInstalls, "Fresh installs must not download automatically")
        updates.automaticallyInstalls = true
        precondition(updates.automaticallyChecks && updates.automaticallyInstalls)
        updates.automaticallyChecks = false
        precondition(!updates.automaticallyChecks && !updates.automaticallyInstalls)
        updates.automaticallyInstalls = true
        precondition(updates.automaticallyChecks, "Opting in must enable checks")
        precondition(updates.supportsGentleScheduledUpdateReminders)
        var changed = false
        updates.onChange = { changed = true }
        updates.standardUserDriverWillFinishUpdateSession()
        precondition(changed && updates.availableVersion == nil)
        let plain = HairpinIcon.image(), badged = HairpinIcon.image(updateAvailable: true)
        precondition(plain.size == badged.size && badged.size == NSSize(width: 18, height: 18))
        precondition(plain.isTemplate && badged.isTemplate)
        precondition(badged.accessibilityDescription?.contains("update available") == true)
        CFPreferencesAppSynchronize(domain as CFString)
        print("Update defaults, opt-in/out and badge geometry verified")
    }
}
