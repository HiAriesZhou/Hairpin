import AppKit
import CoreFoundation

// Compares rendered pixels, alpha included: the count must change the template
// image, and the digits must be cut out rather than painted.
func badgePixels(_ image: NSImage, scale: Int) -> Data {
    let side = Int(image.size.width) * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: side * 4, bitsPerPixel: 32)!
    bitmap.size = image.size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(origin: .zero, size: image.size))
    NSGraphicsContext.restoreGraphicsState()
    return Data(bytes: bitmap.bitmapData!, count: bitmap.bytesPerRow * side)
}

func checkCountBadge() {
    let counts: [Int?] = [nil, -1, 0, 1, 9, 12, 99, 100]
    for scale in [1, 2] {
        let plain = badgePixels(HairpinIcon.image(), scale: scale)
        precondition(plain.contains { $0 != 0 }, "The icon must render something")
        for update in [false, true] {
            let images = counts.map { HairpinIcon.image(updateAvailable: update, badge: $0) }
            precondition(images.allSatisfy { $0.isTemplate && $0.size == NSSize(width: 18, height: 18) })
            let pixels = images.map { badgePixels($0, scale: scale) }
            precondition(pixels[0] == pixels[1] && pixels[0] == pixels[2], "Zero and negative counts draw no badge")
            precondition(pixels[0] != pixels[3] && pixels[3] != pixels[4] && pixels[4] != pixels[5])
            precondition(pixels[6] == pixels[7], "Counts past 99 draw 99")
            precondition(images[7].accessibilityDescription?.contains("100 hidden") == true)
            precondition(images[7].accessibilityDescription?.contains("update available") == update)
        }
    }
    print("Count badges verified at 1x/2x: zero, one/two digits, cap, update dot and accessible count")
}

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
        checkCountBadge()
        let plain = HairpinIcon.image(), badged = HairpinIcon.image(updateAvailable: true)
        precondition(plain.size == badged.size && badged.size == NSSize(width: 18, height: 18))
        precondition(plain.isTemplate && badged.isTemplate)
        precondition(badged.accessibilityDescription?.contains("update available") == true)
        CFPreferencesAppSynchronize(domain as CFString)
        print("Update defaults, opt-in/out and badge geometry verified")
    }
}
