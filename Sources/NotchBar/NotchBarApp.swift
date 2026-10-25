import AppKit

@main
enum NotchBarApp {
    static func main() {
        // The process starts on the main thread; tell the compiler so.
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            withExtendedLifetime(delegate) { app.run() }
        }
    }
}
