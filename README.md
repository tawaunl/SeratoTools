# SeratoTools

SeratoTools is a macOS-native toolkit for maintaining and extending a Serato DJ library.

It includes:

- A SwiftUI desktop app for day-to-day library operations.
- A command-line importer for automation and Finder workflows.
- Core services for parsing and rewriting Serato library/crate files safely.

The project is organized as Swift Package Manager targets:

- `SeratoToolsApp` (GUI)
- `SeratoToolsCLI` (CLI)
- `SeratoToolsCore` (shared parsing/services/writing)

## Why SeratoTools

Serato libraries can get messy over time: moved files, split folders, inconsistent metadata, and slow manual crate updates.
SeratoTools focuses on practical, high-impact workflows that keep your library playable and organized while preserving Serato compatibility.

## Feature Highlights

### 1) Tracks Workspace

- Loads your Serato library and track database.
- Lets you browse tracks and inspect metadata.
- Includes quick delete actions with confirmation controls.
- Supports track metadata editing with online and fingerprint-assisted lookup.

### 2) PlaylistMatch

- Accepts playlist input from:
  - Spotify playlist URLs
  - CSV files (Title/Artist style)
  - Plain text lists like `Artist - Title`
- Scans your existing Serato library for matches.
- Shows confidence/reasoning and version choices per match.
- Creates crates from chosen matches.
- Keeps unmatched tracks in a "Plan" workflow.
- Supports YouTube search/rip assist for unresolved tracks.

### 3) Add Music

- Imports files and folders into your main music folder.
- Supports move or copy transfer modes.
- Discovers supported audio files recursively.
- Creates a dated crate (or targets an existing crate / no crate).
- Includes folder sync into Serato DB flows.

### 4) YouTube Rip

- Handles one or many YouTube links in a batch.
- Supports link import from text/CSV-like lists.
- Downloads audio to your chosen destination using `yt-dlp` + `ffmpeg`.
- Can write imported tracks into dated or existing crates.
- Supports output format, quality, and bitrate choices.
- Includes optional ID3 metadata editing and online metadata lookup.

### 5) Crates

- Displays crate and smart crate hierarchy.
- Supports crate-level navigation and filtering.
- Surfaces crate stats (counts, smart, hidden, etc.).
- Provides crate detail browsing and track table actions.

### 6) Tags (Bulk Metadata)

- Scope-based editing (All Tracks or specific crate/smart crate).
- Bulk apply for Artist / Genre / Year.
- "Only Fill Empty" mode to avoid overwriting existing metadata.
- Completion stats by scope versus whole-library baseline.
- Single-track deep metadata edit via lookup sheet.

### 7) Missing Tracks

- Detects missing library entries.
- Scans for candidate moved/renamed files.
- Allows explicit per-track repair (no silent auto-apply).
- Can gather unresolved items into a review crate.

### 8) Backup

- Creates timestamped backups in `SeratoBackups`.
- Backup modes:
  - Full
  - Incremental
  - Single-crate package
- Shows pre-backup estimates (tracks, crates, size).

### 9) Library Consolidation

- Analyzes scattered source locations across your collection.
- Moves or copies tracks into one central destination.
- Rewrites Serato paths so crates/library references stay valid.
- Lets you select which source groups to process.
- Checks destination capacity for copy mode planning.

## CLI Workflow

`SeratoToolsCLI` provides Add Music import automation.

Usage:

```bash
swift run SeratoToolsCLI --help
```

Common example:

```bash
swift run SeratoToolsCLI \
  --mode move \
  --destination "$HOME/Music" \
  --crate-prefix "New Music" \
  -- ~/Downloads/incoming ~/Desktop/track.mp3
```

CLI options:

- `-d, --destination <path>` destination folder (default `~/Music`)
- `-c, --crate-prefix <name>` dated crate prefix (default `New Music`)
- `-m, --mode <move|copy>` transfer mode
- `-l, --library-dir <path>` override `_Serato_` directory
- `-h, --help` show help

## Finder Quick Action

The repository includes an install script for a Finder Quick Action (`Add To Serato Library`) powered by `SeratoToolsCLI`.

Install from repo:

```bash
./Scripts/install-finder-quick-action.sh
```

Install from packaged app:

```bash
/Applications/SeratoTools.app/Contents/Resources/scripts/install-finder-quick-action.sh
```

Supported env vars for Quick Action behavior:

- `SERATOTOOLS_ADD_MODE` (`move` or `copy`)
- `SERATOTOOLS_ADD_DESTINATION`
- `SERATOTOOLS_ADD_CRATE_PREFIX`
- `SERATOTOOLS_LIBRARY_DIR`

## Safety and Data Integrity

SeratoTools is designed around safe write behavior:

- Uses explicit user actions for risky operations.
- Avoids silent missing-track auto-fixes.
- Uses backup and atomic write strategies in core safety services.
- Emphasizes user-readable errors (`LocalizedError`) for actionable failure states.

## Library Discovery and Path Handling

SeratoTools can locate `_Serato_` via:

1. `SERATOTOOLS_LIBRARY_DIR`
2. user defaults override
3. auto-detection from valid library locations
4. fallback to `~/Music/_Serato_`

It handles Serato path conventions and external-volume layouts when resolving and rewriting track paths.

## Requirements

- macOS 14+
- Swift 6 toolchain
- For YouTube features: `yt-dlp` and `ffmpeg`
- For audio fingerprint lookup: `fpcalc` (Chromaprint)
- Optional metadata source token:
  - `SERATOTOOLS_DISCOGS_TOKEN` (or saved Discogs token)
- Optional fingerprint token:
  - `SERATOTOOLS_ACOUSTID_KEY` (or saved AcoustID key)

## Build and Run

Build all targets:

```bash
swift build
```

Run GUI app target:

```bash
swift run SeratoTools
```

Run CLI target:

```bash
swift run SeratoToolsCLI --help
```

## Tests

Run core tests:

```bash
swift test
```

## Packaging

Build standalone app bundle:

```bash
./Scripts/build-app.sh
```

Build installer package:

```bash
./Scripts/build-installer.sh
```

Outputs are written to `dist/`.

## Project Layout

- `Sources/SeratoToolsApp/` SwiftUI app and feature views
- `Sources/SeratoToolsCLI/` command-line entrypoint
- `Sources/SeratoToolsCore/` parsers, models, safety, services, writers
- `Scripts/` build/package/install helpers
- `docs/` architecture notes, packaging docs, roadmap, engineering rules
- `Tests/SeratoToolsCoreTests/` core behavior and format tests

## Additional Docs

- `docs/ROADMAP.md` phased feature direction and architecture notes
- `docs/PACKAGING_STANDALONE.md` app/pkg packaging details
- `docs/FINDER_QUICK_ACTION_ADD_MUSIC.md` Finder integration details
- `docs/ENGINEERING_RULES.md` coding and error-handling standards

## Status

Active development with strong focus on practical DJ workflows, safe library mutation, and clear, user-actionable error handling.
