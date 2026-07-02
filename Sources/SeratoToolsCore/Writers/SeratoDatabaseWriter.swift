import Foundation

public struct SeratoTrackMetadataUpdate: Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var genre: String
    public var comment: String
    public var key: String
    public var bpm: Double?
    public var year: Int?

    public init(
        title: String,
        artist: String,
        album: String,
        genre: String,
        comment: String,
        key: String,
        bpm: Double?,
        year: Int?
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.genre = genre
        self.comment = comment
        self.key = key
        self.bpm = bpm
        self.year = year
    }
}

/// Writes changes to a `database V2` file's bytes.
///
/// Rewriting is done surgically at the chunk level rather than by fully
/// re-serializing a parsed `[Track]` model: every `otrk` record that isn't
/// being changed is copied through byte-for-byte, including any fields this
/// codebase doesn't parse into `Track`. Round-tripping through a model
/// would silently drop fields Serato understands but we don't yet model —
/// unacceptable for a file a bug could corrupt in a real user's library.
public enum SeratoDatabaseWriter {
    /// Rewrites the `pfil` field of every `otrk` record whose current
    /// decoded path equals `oldPath`, replacing it with `newPath`. Returns
    /// the new file contents and whether any record was actually changed.
    public static func rewritingPath(
        _ oldPath: String,
        to newPath: String,
        in fileData: Data
    ) -> (data: Data, didRewrite: Bool) {
        var didRewrite = false
        let topLevel = SeratoChunkCodec.readChunks(from: fileData)

        let newChunks: [SeratoChunk] = topLevel.map { chunk in
            guard chunk.tag == "otrk" else { return chunk }
            let fields = SeratoChunkCodec.readChunks(from: chunk.payload)
            guard
                let pfilField = fields.first(where: { $0.tag == "pfil" }),
                SeratoChunkCodec.decodeUTF16BEString(pfilField.payload) == oldPath
            else {
                return chunk
            }

            didRewrite = true
            let newFields = fields.map { field -> SeratoChunk in
                guard field.tag == "pfil" else { return field }
                return SeratoChunk(tag: "pfil", payload: SeratoChunkCodec.encodeUTF16BEString(newPath))
            }
            return SeratoChunk(tag: "otrk", payload: SeratoChunkCodec.writeChunks(newFields))
        }

        return (SeratoChunkCodec.writeChunks(newChunks), didRewrite)
    }

    /// Removes every `otrk` record whose `pfil` equals any of `paths`.
    /// Returns rewritten bytes and whether at least one record was removed.
    public static func removingPaths(
        _ paths: Set<String>,
        in fileData: Data
    ) -> (data: Data, didRewrite: Bool) {
        guard !paths.isEmpty else {
            return (fileData, false)
        }

        var didRewrite = false
        let topLevel = SeratoChunkCodec.readChunks(from: fileData)

        let newChunks: [SeratoChunk] = topLevel.filter { chunk in
            guard chunk.tag == "otrk" else { return true }
            let fields = SeratoChunkCodec.readChunks(from: chunk.payload)
            guard let pfilField = fields.first(where: { $0.tag == "pfil" }) else {
                return true
            }
            let path = SeratoChunkCodec.decodeUTF16BEString(pfilField.payload)

            if paths.contains(path) {
                didRewrite = true
                return false
            }
            return true
        }

        return (SeratoChunkCodec.writeChunks(newChunks), didRewrite)
    }

    /// Rewrites selected metadata fields in the `otrk` whose `pfil` matches
    /// `storedPath`.
    public static func rewritingMetadata(
        forStoredPath storedPath: String,
        metadata: SeratoTrackMetadataUpdate,
        in fileData: Data
    ) -> (data: Data, didRewrite: Bool) {
        var didRewrite = false
        let topLevel = SeratoChunkCodec.readChunks(from: fileData)

        let newChunks: [SeratoChunk] = topLevel.map { chunk in
            guard chunk.tag == "otrk" else { return chunk }
            var fields = SeratoChunkCodec.readChunks(from: chunk.payload)
            guard
                let pfilField = fields.first(where: { $0.tag == "pfil" }),
                SeratoChunkCodec.decodeUTF16BEString(pfilField.payload) == storedPath
            else {
                return chunk
            }

            didRewrite = true
            upsertStringField("tsng", value: metadata.title, in: &fields)
            upsertStringField("tart", value: metadata.artist, in: &fields)
            upsertStringField("talb", value: metadata.album, in: &fields)
            upsertStringField("tgen", value: metadata.genre, in: &fields)
            upsertStringField("tcom", value: metadata.comment, in: &fields)
            upsertStringField("tkey", value: metadata.key, in: &fields)
            upsertStringField("tbpm", value: metadata.bpm.map { String(format: "%.0f", $0) } ?? "", in: &fields)
            upsertStringField("ttyr", value: metadata.year.map(String.init) ?? "", in: &fields)

            return SeratoChunk(tag: "otrk", payload: SeratoChunkCodec.writeChunks(fields))
        }

        return (SeratoChunkCodec.writeChunks(newChunks), didRewrite)
    }

    private static func upsertStringField(_ tag: String, value: String, in fields: inout [SeratoChunk]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = fields.firstIndex(where: { $0.tag == tag }) {
            if trimmed.isEmpty {
                fields.remove(at: index)
            } else {
                fields[index] = SeratoChunk(tag: tag, payload: SeratoChunkCodec.encodeUTF16BEString(trimmed))
            }
            return
        }

        guard !trimmed.isEmpty else { return }
        fields.append(SeratoChunk(tag: tag, payload: SeratoChunkCodec.encodeUTF16BEString(trimmed)))
    }
}
