# Contributing to EZLibrary

Thanks for your interest in improving EZLibrary! This project is a community-built,
open source toolkit for DJs and hobbyists who want a cleaner, safer Serato library.
Contributions of all kinds are welcome — bug reports, feature ideas, documentation,
and code.

By contributing, you agree that your contributions will be licensed under the
project's [GNU General Public License v3.0](LICENSE).

## Ways to Contribute

- **Report bugs** — Open a [bug report](https://github.com/tawaunl/EZLibrary/issues/new/choose)
  with clear steps to reproduce.
- **Request features** — Open a feature request describing the DJ/library workflow you'd like to see.
- **Improve docs** — Fixes to the README or files under `docs/` are always appreciated.
- **Write code** — Fix a bug or implement a feature. See the workflow below.

> [!IMPORTANT]
> EZLibrary reads and writes real Serato library data. Always test against a
> throwaway copy of a library, never your primary collection. Preserve the
> project's backup + atomic-write + verification patterns for any operation that
> mutates a user's library.

## Development Setup

You'll need macOS 14+ and the Swift toolchain (Xcode or the Command Line Tools).

```bash
# Build everything
swift build

# Run the app
swift run EZLibrary

# Run the CLI
swift run EZLibraryCLI --help

# Run the test suite
swift test
```

### Pointing at a test library

Set `SERATOTOOLS_LIBRARY_DIR` to run against a safe, disposable `_Serato_` directory
instead of your real one:

```bash
SERATOTOOLS_LIBRARY_DIR="/tmp/_Serato_" swift run EZLibrary
```

## Pull Request Workflow

1. Fork the repository and create a branch from `main`
   (e.g. `feature/short-description` or `fix/short-description`).
2. Make your change, keeping edits focused and scoped to the task.
3. Add or update tests under `Tests/EZLibraryCoreTests/` for any behavior change.
4. Make sure the build and tests pass locally:
   ```bash
   swift build
   swift test
   ```
5. Open a pull request describing **what** changed and **why**, and link any
   related issue.

## Coding Guidelines

- Follow the rules in [docs/ENGINEERING_RULES.md](docs/ENGINEERING_RULES.md).
  In particular, every new user-facing error must conform to `LocalizedError`
  with a clear `errorDescription` (and `recoverySuggestion` where useful).
- Keep changes minimal and idiomatic; avoid unrelated refactors in the same PR.
- Prefer adding logic to `EZLibraryCore` (with tests) over view code, so it can be
  shared and verified.
- Do not commit network-dependent live tests; keep tests offline and deterministic.
- Match the existing code style and naming conventions already used in the file.

## Reporting Security Issues

If you discover a security or data-loss vulnerability, please do **not** open a
public issue. Instead, contact the maintainer privately so it can be addressed
before disclosure.

## Code of Conduct

This project follows a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you
are expected to uphold it.
