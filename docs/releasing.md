# Releasing Hairpin

Releases are signed with a Developer ID, notarized by Apple and published by CI.

## Cutting a release

1. Merge everything for the release into `main` through pull requests.
2. Tag `main` and push the tag (only the maintainer can create `v*` tags):
   ```sh
   git tag -a v0.3.0 -m "Hairpin 0.3.0" && git push origin v0.3.0
   ```
3. CI's `build` job builds and tests as usual, then the `release` job signs the app and nested Sparkle code with the hardened runtime, notarizes and staples the app and disk image, and creates a **draft** GitHub Release. It generates a signed `appcast.xml` from the final DMG, verifies it with the bundled public key, uploads `Hairpin.zip`, `Hairpin.dmg` and the feed, downloads all three to compare their bytes, then publishes the complete release as latest. A failed job leaves the previous stable release available. Published releases are immutable in this workflow; reruns may replace assets only on a draft.

The feed URL is `https://github.com/HiAriesZhou/Hairpin/releases/latest/download/appcast.xml`.
Every enclosure uses `releases/download/vX.Y.Z/Hairpin.dmg`, not `latest`.
The feed signature is embedded in its final XML comment; there is no separate
signature asset. Never edit a signed feed without regenerating its signature.
Release notes are embedded as text, without external content or JavaScript.
The last three feed items per OS branch are retained; delta updates are disabled.

`CFBundleVersion` defaults to the Git commit count. The release gate rejects a
build that is not greater than every build in the previous signed stable feed.
Use a new commit/tag for a correction; do not retag an existing release.
Users on 0.2.3 and earlier must manually install an updater-capable version once.

The website's download button and the README link to `releases/latest/download/Hairpin.dmg`, so every release must be a full (not pre-) release with an asset named exactly `Hairpin.dmg`. GitHub's "latest" skips pre-releases, and a renamed asset breaks the link.

## Secrets

Configure these six repository secrets in Settings › Secrets and variables › Actions. Only the `release` job reads them; the `build` job and pull requests from forks never get them.

| Secret | What it is |
|---|---|
| `MACOS_CERT_P12_BASE64` | The Developer ID Application certificate and its private key, exported from Keychain Access as `.p12`, base64-encoded |
| `MACOS_CERT_PASSWORD` | The password chosen for that `.p12` |
| `NOTARY_KEY_P8_BASE64` | An App Store Connect API key (`AuthKey_….p8`, Developer role is enough), base64-encoded |
| `NOTARY_KEY_ID` | That key's ID |
| `NOTARY_ISSUER_ID` | The issuer ID shown above the keys in App Store Connect |
| `SPARKLE_PRIVATE_KEY` | The private Ed25519 seed exported by Sparkle's `generate_keys`; passed to `generate_appcast` through stdin, never command arguments |

The workflow decodes Apple credentials into files under the runner's temporary directory, never prints them, uploads only release assets, and deletes the keychain and files when the job ends. The Sparkle private key stays in the secret environment and stdin. If an Apple secret leaks, revoke the certificate or key at developer.apple.com / App Store Connect and replace the secret.

## Update signing key

The public key lives in `scripts/sparkle-public-key.txt` and is embedded in the
bundle. Keep a secure backup of its private key outside the repository. Local
signing uses Keychain account `hairpin-updates`; do not reuse another project's
key. The pinned Sparkle tools are available after `swift package resolve` at
`.build/artifacts/sparkle/Sparkle/bin/`.

For a new fork, generate a dedicated key using `generate_keys --account
hairpin-updates`, replace the public key file, and securely transfer the exported
private key into the Actions secret. Never print or commit the exported file.
Losing the private key prevents signing updates trusted by installed apps;
restoring its backup is preferable to changing the public key. A suspected
compromise requires a deliberate key migration/security release, not an
unreviewed replacement of the public key.

Removing an item from a newly signed feed can halt further rollout. It cannot
downgrade apps that already updated; ship a corrected higher build instead.

## Signing locally

The same scripts work on a Mac with the certificate in its keychain:

```sh
SIGN_IDENTITY="Developer ID Application: …" VERSION=0.3.0 scripts/bundle.sh   # or the identity's SHA-1
NOTARY_KEY_PATH=… NOTARY_KEY_ID=… NOTARY_ISSUER_ID=… scripts/notarize.sh app
SIGN_IDENTITY="…" scripts/dmg.sh
NOTARY_KEY_PATH=… NOTARY_KEY_ID=… NOTARY_ISSUER_ID=… scripts/notarize.sh dmg
scripts/appcast.sh v0.3.0 release-notes.txt previous-appcast.xml
```

Omit the previous-feed argument only for the first updater release. Keep release
notes and downloaded feeds outside tracked source. The generated feed is
`.build/update-feed/appcast.xml`. `scripts/ValidateUpdateFeed.swift` verifies
Ed25519 feed/archive signatures, version, build monotonicity, download URL and
payload length with the public key and no private-key access.
