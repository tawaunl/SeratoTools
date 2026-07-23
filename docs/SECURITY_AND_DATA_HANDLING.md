# Security and Data Handling

EZLibrary reads and writes files in your Serato library. This document explains what
the app touches, how it protects your data, and what you should know before running
it.

For a deeper, code-referenced explanation of the write pipeline, see
[DATA_SAFETY.md](DATA_SAFETY.md). To report a security vulnerability privately, see
[SECURITY.md](../SECURITY.md).

## What EZLibrary accesses

- Your Serato library database and crate files (typically under `~/Music/_Serato_`)
- Audio files you choose to import, tag, or move
- Optional: Discogs and AcoustID APIs for metadata lookup, only when you provide
  your own API token/key (`EZLIBRARY_DISCOGS_TOKEN` / `EZLIBRARY_ACOUSTID_KEY`)
- Optional: YouTube / SoundCloud links you provide, only when you use the
  Download Audio feature

EZLibrary does not send your library data, file paths, or metadata to any server
controlled by this project. Metadata lookups go directly from your machine to the
third-party service you've configured (Discogs, AcoustID), using your own
credentials.

## How writes are protected

Every operation that modifies your library data follows the same safety pattern:

1. **Backup first.** Before any bulk operation (tag edits, consolidation,
   missing-track repair), EZLibrary can write a timestamped backup to a
   `SeratoBackups` folder, and you can preview the size and scope before committing.
   In addition, every individual write automatically snapshots the target Serato
   file first.
2. **Atomic writes.** Files are written to a temporary location and only swapped
   into place once the write completes successfully. A crash or interruption
   mid-write should not leave a corrupted or half-written crate file.
3. **Read-back verification.** After a metadata write, EZLibrary re-reads what it
   wrote and confirms the change actually persisted before reporting success. If a
   later step fails, a renamed file is rolled back to its original path.
4. **Explicit confirmation for sensitive operations.** Bulk edits, consolidation,
   and missing-track fixes require you to review and confirm scope before anything
   is written. Nothing silently auto-repairs your library in the background.
5. **Readable failure messages.** If an operation fails, EZLibrary surfaces a
   specific, human-readable error rather than failing silently or leaving you to
   guess what happened.

It also refuses to write to `database V2` / `.crate` files while Serato itself is
running, to avoid Serato clobbering your edit on its next save.

## What to do before trusting this (or any) tool with your library

- Keep your own independent backup of `~/Music/_Serato_` before running any bulk
  operation, regardless of what any tool claims about safety.
- Check the commit history and test coverage of any library-management tool before
  granting it write access.
- Review what third-party services a tool talks to, and whether it's sending your
  data anywhere you didn't explicitly authorize.

## Known risk areas

- **Download Audio feature**: downloads audio via `yt-dlp` based on YouTube /
  SoundCloud links you provide. This is a distinct workflow from library management
  and doesn't touch your existing crates directly, but you should only use it with
  content you have the rights to.
- **Third-party API keys**: if you configure a Discogs or AcoustID token, that key
  is stored locally and used only for the lookups you trigger. Treat it like any
  other credential.

## Reporting a security or data issue

- **Security vulnerabilities or unintended data-exposure risks** — please report
  privately and do **not** open a public issue. See [SECURITY.md](../SECURITY.md).
- **Non-sensitive data-safety bugs** (loss or corruption) — open an issue at
  <https://github.com/tawaunl/EZLibrary/issues> with as much detail as possible.

Data-safety issues are prioritized over feature requests.
