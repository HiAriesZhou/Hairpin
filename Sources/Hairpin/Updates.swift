import AppKit
import Sparkle

/// Sparkle owns scheduling, preferences, verification and installation. Hairpin
/// only replaces scheduled alerts with a quiet, reachable menu bar reminder.
@MainActor
final class Updates: NSObject, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    var onChange: (() -> Void)?
    private(set) var availableVersion: String? {
        didSet { onChange?() }
    }
    private var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false,
                                                  updaterDelegate: self, userDriverDelegate: self)
        controller.updater.sendsSystemProfile = false
    }

    func start() {
        controller.startUpdater()
    }

    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            // Turning checks off must also stop future automatic downloads.
            if !newValue { controller.updater.automaticallyDownloadsUpdates = false }
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }

    var automaticallyInstalls: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set {
            if newValue { controller.updater.automaticallyChecksForUpdates = true }
            controller.updater.automaticallyDownloadsUpdates = newValue
        }
    }

    // Sparkle can resume a pending update even while a check is in progress.
    var canCheck: Bool { controller.updater.canCheckForUpdates }

    func check() {
        controller.checkForUpdates(nil)
    }

    func allowedSystemProfileKeys(for updater: SPUUpdater) -> [String]? { [] }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool { false }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        if !handleShowingUpdate { availableVersion = update.displayVersionString }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        availableVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        availableVersion = nil
    }

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        availableVersion = item.displayVersionString
        return false // Sparkle keeps control and installs when Hairpin quits.
    }
}
