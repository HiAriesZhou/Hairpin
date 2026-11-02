# Security policy

Hairpin holds two sensitive macOS permissions: Accessibility (to read and press other apps' menu bar items) and, optionally, Screen Recording (to capture the menu bar strip for icon shapes). A flaw that lets it, or anyone through it, read, press or capture more than that is a security issue.

Updates use a pinned Sparkle framework. Both the update feed and DMG require
Ed25519 verification against the public key embedded in the app, before
extraction. Release apps and nested helpers are Developer ID signed and
notarized. Update checks/downloads are the only network use; system profiling
and release-note JavaScript are disabled. A verification failure must leave the
installed app usable. Report any bypass of these boundaries privately.

## Reporting a vulnerability

Please report it privately: on GitHub, open the **Security** tab of this repository and choose **Report a vulnerability**. Don't open a public issue or pull request for it.

Include what you found, how to reproduce it, the Hairpin version and the macOS version. You'll get a reply within a week; once it's fixed, the fix ships in a new release and the advisory is published with credit, unless you'd rather not be named.

## Supported versions

Only the latest release gets security fixes.
