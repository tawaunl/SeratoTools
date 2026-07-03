# Finder Quick Action: Add Music

This project now includes a command-line importer and helper script so Finder
right-click imports can flow into SeratoTools.

## What it does

- Accepts selected files and/or folders from Finder.
- Imports supported audio formats (`mp3`, `m4a`, `aac`, `wav`, `aif`, `aiff`, `flac`, `alac`, `ogg`) into your main music folder.
- Creates a dated crate in your Serato `Subcrates` folder.
- Runs while Serato is open for quick add workflow.

## One-time setup in Automator

1. Open Automator.
2. Create a new `Quick Action`.
3. Configure:
   - `Workflow receives current`: `files or folders`
   - `in`: `Finder`
4. Add `Run Shell Script` action.
5. Set:
   - `Shell`: `/bin/bash`
   - `Pass input`: `as arguments`
6. Use this script body (update the repository path if needed):

```bash
export SERATOTOOLS_ADD_MODE=move
export SERATOTOOLS_ADD_DESTINATION="$HOME/Music"
export SERATOTOOLS_ADD_CRATE_PREFIX="New Music"

/Users/tawaunlucas/projects/SeratoTools/Scripts/finder-add-music.sh "$@"
```

7. Save as `Add To Serato Library`.

Now right-click any files/folders in Finder and run `Quick Actions` -> `Add To Serato Library`.

## Configuration via environment variables

- `SERATOTOOLS_ADD_MODE`: `move` or `copy` (default `move`)
- `SERATOTOOLS_ADD_DESTINATION`: destination main music folder (default `~/Music`)
- `SERATOTOOLS_ADD_CRATE_PREFIX`: crate prefix before date (default `New Music`)
- `SERATOTOOLS_LIBRARY_DIR`: optional explicit `_Serato_` directory override

## Direct CLI usage

From repository root:

```bash
swift run SeratoToolsCLI --mode move --destination "$HOME/Music" --crate-prefix "New Music" -- ~/Downloads/incoming
```
