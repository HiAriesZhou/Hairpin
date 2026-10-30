# Engineering rules

Hairpin is a small macOS menu bar utility for reaching hidden status items.
Keep changes within that scope. Read [CONTRIBUTING.md](CONTRIBUTING.md),
[the architecture notes](docs/how-it-works.md) and the relevant parts of
[ACCEPTANCE.md](ACCEPTANCE.md) before changing behavior.

## Public repository and privacy

- This repository is public and MIT licensed. Keep the license and required
  copyright notices; use only code and assets that permit MIT distribution.
- Retain the existing website author branding and README author credit. These
  approved public credits do not permit adding personal information elsewhere.
- Do not add personal profiles, avatars, contact details, private account or
  device information, absolute local paths, user data, raw session transcripts,
  or private business information. Public project links and required license
  notices are appropriate repository content.
- Never commit credentials, signing material, tokens, or real credential values
  in examples. Review logs, screenshots, fixtures and generated files for
  private information before including them. Use synthetic examples.
- Keep task plans, progress notes, handoff snapshots and audit reports out of
  commits. Use the ignored `.local/` directory for local process records;
  keep raw session logs and private diagnostics outside the repository.
- Preserve the app's privacy boundaries: no network connections, keystroke
  logging or app-window content capture. Icon captures cover only the menu bar
  strip and stay in memory. Accessibility reads and actions serve menu bar use.

## Architecture and behavior

- Keep classification, ordering, geometry and placement in `HairpinCore`,
  without AppKit dependencies, and cover changed logic with meaningful tests.
  `Hairpin` owns AppKit, Accessibility, capture and login integration.
- Run Accessibility scans and presses off the main thread, with bounded
  messaging timeouts. Opening the row uses the latest snapshot.
- Judge items on the notched display, or the primary display without a notch.
  Displays can order their status windows differently; preserve window-owner
  tracking. Cache icon looks by process and status window, not volatile text or
  an item's position among Accessibility children.
- With no hidden items, show no separate pin. While Hairpin's own icon is visible
  in the target menu bar, use it instead of a separate pin. Include any item
  intentionally covered by the pin in the expanded row.
- Keep Accessibility required and Screen Recording optional. Retain fallbacks
  for older supported macOS versions and unavailable icon captures.

## Verification and delivery

- Use `swift build` and `swift test`; packaging checks are `scripts/bundle.sh`
  and then `scripts/dmg.sh`. These commands generate files. Bundle scripts
  replace existing root-level artifacts; inspect them before running.
- Verify visible changes on a notched Mac using the relevant acceptance checks.
  Record only the environment details needed to reproduce results, without
  identifiers or private screen content. Distinguish checks run from pending
  checks; automated tests do not establish manual acceptance.
- Preserve existing work. Use a task branch and a pull request for changes to
  `main`; the `build` check must pass. Keep logical changes separate and have
  another reviewer inspect the diff. Merge by squash or rebase.
- Follow [docs/releasing.md](docs/releasing.md) for authorized releases. Versions
  come from `VERSION` or an exact tag on HEAD; untagged builds default to
  `0.0.0`. Formal releases must include `Hairpin.dmg` and `Hairpin.zip`, keeping
  the latest-release download URL working.
- Installing or replacing an app, resetting permissions, signing, notarizing,
  pushing, merging and publishing require authorization for the current task.
  An acceptance checklist or an old session is not authorization.
- Keep README as the entry point. Put implementation details in the existing
  [architecture notes](docs/how-it-works.md). Only reusable project documentation
  belongs in `docs/`.
  Preserve any existing `CLAUDE.md` when updating shared engineering rules.
