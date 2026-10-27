# Contributing to Hairpin

Thanks for helping. Hairpin is small on purpose: it holds the menu bar items hidden by the notch, and that's all. Changes that keep it that way are the easiest to take.

## Before you start

- **Bugs**: open an issue with your Mac model, macOS version, Hairpin version, what you expected and what happened. A screenshot of the menu bar helps.
- **Features or larger changes**: open an issue first so we can agree on the approach before you write code.
- **Security issues**: don't file them publicly; see [SECURITY.md](SECURITY.md).

## Making a change

1. Fork the repository and branch off `main`.
2. Keep the split between the two modules: `HairpinCore` is pure, AppKit-free logic (classification, ordering, placement) with unit tests; `Hairpin` is the AppKit app around it. Logic that can be tested belongs in `HairpinCore`, with a test.
3. Run the checks:
   ```sh
   swift test             # unit tests
   scripts/bundle.sh      # builds Hairpin.app and Hairpin.zip
   ```
   For changes you can see, run the app on a notched Mac and walk through the matching part of [ACCEPTANCE.md](ACCEPTANCE.md). Say in the pull request what you checked and on which macOS version.
4. Open a pull request against `main`. Describe what changed and why, and link the issue.

## How pull requests are merged

- `main` is protected: every change, the maintainer's included, goes through a pull request, the `build` check (CI) must pass, and review conversations must be resolved.
- CI on a pull request from a fork waits for the maintainer to approve the run.
- The maintainer reviews and merges, by squash or rebase; there are no merge commits.

## License of contributions

Hairpin is under the [MIT License](LICENSE). By opening a pull request you agree that your contribution is licensed under the same terms (inbound = outbound); there's no separate contributor agreement to sign. Only contribute work you have the right to license this way.

Hairpin is written from scratch. Don't copy code from other menu bar managers or other projects whose licenses don't allow it under MIT; ideas are welcome, copied code is not.
