# Releasing Hairpin

Releases are signed with a Developer ID, notarized by Apple and published by CI.

## Cutting a release

1. Merge everything for the release into `main` through pull requests.
2. Tag `main` and push the tag (only the maintainer can create `v*` tags):
   ```sh
   git tag -a v0.3.0 -m "Hairpin 0.3.0" && git push origin v0.3.0
   ```
3. CI's `build` job builds and tests as usual. The `release` job then waits on the **release** environment: approve it under the run's **Review deployments**.
4. The job signs the app with the hardened runtime, notarizes and staples it, builds and notarizes the disk image, and publishes `Hairpin.zip` and `Hairpin.dmg` on a GitHub Release with generated notes. Edit the notes afterwards if you like.

## Secrets

The **release** environment (Settings › Environments) holds them; no other job can read them, and pull requests from forks never run with them.

| Secret | What it is |
|---|---|
| `MACOS_CERT_P12_BASE64` | The Developer ID Application certificate and its private key, exported from Keychain Access as `.p12`, base64-encoded |
| `MACOS_CERT_PASSWORD` | The password chosen for that `.p12` |
| `NOTARY_KEY_P8_BASE64` | An App Store Connect API key (`AuthKey_….p8`, Developer role is enough), base64-encoded |
| `NOTARY_KEY_ID` | That key's ID |
| `NOTARY_ISSUER_ID` | The issuer ID shown above the keys in App Store Connect |

The workflow decodes them into files under the runner's temporary directory, never prints them, uploads only the signed `Hairpin.zip` and `Hairpin.dmg`, and deletes the keychain and files when the job ends. If a secret leaks, revoke the certificate or key at developer.apple.com / App Store Connect and replace the secret.

## Signing locally

The same scripts work on a Mac with the certificate in its keychain:

```sh
SIGN_IDENTITY="Developer ID Application: …" VERSION=0.3.0 scripts/bundle.sh   # or the identity's SHA-1
NOTARY_KEY_PATH=… NOTARY_KEY_ID=… NOTARY_ISSUER_ID=… scripts/notarize.sh app
SIGN_IDENTITY="…" scripts/dmg.sh
NOTARY_KEY_PATH=… NOTARY_KEY_ID=… NOTARY_ISSUER_ID=… scripts/notarize.sh dmg
```
