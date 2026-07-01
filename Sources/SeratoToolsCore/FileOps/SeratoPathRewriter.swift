import Foundation

/// The single choke point every feature should use to rewrite a track's
/// stored path in `database V2`. Composes the Safety/ primitives in the
/// correct order — nothing else should call `AtomicFileWriter` or
/// `SeratoDatabaseWriter` directly for this purpose.
public enum SeratoPathRewriter {
    public enum RewriteError: Error, Equatable {
        /// Refuse to write while Serato itself might also be writing to
        /// the same file.
        case seratoIsRunning
        /// `oldPath` didn't match any track — failing loud here (rather
        /// than silently writing back identical bytes) surfaces caller
        /// bugs immediately instead of a mysterious no-op.
        case trackNotFound
    }

    @discardableResult
    public static func rewritePath(
        _ oldPath: String,
        to newPath: String,
        in databaseFileURL: URL
    ) throws -> Bool {
        guard !SeratoProcessGuard.isSeratoRunning else {
            throw RewriteError.seratoIsRunning
        }

        try SeratoBackupBeforeWrite.snapshot(of: databaseFileURL)

        let data = try Data(contentsOf: databaseFileURL)
        let (newData, didRewrite) = SeratoDatabaseWriter.rewritingPath(oldPath, to: newPath, in: data)
        guard didRewrite else {
            throw RewriteError.trackNotFound
        }

        try AtomicFileWriter.write(newData, to: databaseFileURL)
        return true
    }
}
