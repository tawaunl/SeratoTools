import SwiftUI
import AVFoundation
import SeratoToolsCore

struct TrackHotCuePoint: Codable, Identifiable, Hashable {
    let slot: Int
    var timeSeconds: Double
    var name: String
    var colorHex: String

    var id: Int { slot }
}

enum TrackHotCueCacheStore {
    private static let defaultsKey = "SeratoToolsTrackHotCuesV1"

    static func load(for track: Track) -> [TrackHotCuePoint] {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let map = try? JSONDecoder().decode([String: [TrackHotCuePoint]].self, from: data)
        else {
            return []
        }
        return (map[track.seratoStoredPath] ?? []).sorted { $0.slot < $1.slot }
    }

    static func save(_ cues: [TrackHotCuePoint], for track: Track) {
        var map: [String: [TrackHotCuePoint]] = [:]
        if
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let existing = try? JSONDecoder().decode([String: [TrackHotCuePoint]].self, from: data)
        {
            map = existing
        }

        map[track.seratoStoredPath] = normalized(cues)
        if let encoded = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }

    private static func normalized(_ cues: [TrackHotCuePoint]) -> [TrackHotCuePoint] {
        cues
            .filter { $0.slot >= 1 && $0.slot <= 8 }
            .sorted { $0.slot < $1.slot }
    }
}

enum TrackHotCueMetadataStore {
    private static let markerDescription = "SERATOTOOLS_HOTCUES_V1"

    static func load(for track: Track) -> [TrackHotCuePoint] {
        guard track.fileURL.pathExtension.lowercased() == "mp3" else {
            return []
        }
        guard let data = try? Data(contentsOf: track.fileURL) else {
            return []
        }

        let parsed = parseID3Tag(from: data)
        guard let parsed else {
            return []
        }

        for frame in parsed.frames.reversed() {
            guard frame.id == "TXXX" else { continue }
            let pair = decodeUserTextFrame(frame.payload)
            guard pair.description == markerDescription else { continue }
            guard let json = pair.value.data(using: .utf8) else { continue }
            guard let cues = try? JSONDecoder().decode([TrackHotCuePoint].self, from: json) else { continue }
            return cues
                .filter { $0.slot >= 1 && $0.slot <= 8 }
                .sorted { $0.slot < $1.slot }
        }

        return []
    }

    static func save(_ cues: [TrackHotCuePoint], for track: Track) {
        guard track.fileURL.pathExtension.lowercased() == "mp3" else {
            return
        }
        guard let originalData = try? Data(contentsOf: track.fileURL) else {
            return
        }

        let existing = parseID3Tag(from: originalData)
        let audioBody = existing?.audioBody ?? originalData
        let originalFrames = existing?.frames ?? []
        let version = existing?.versionMajor ?? 4

        var frames = originalFrames.filter { frame in
            guard frame.id == "TXXX" else { return true }
            let pair = decodeUserTextFrame(frame.payload)
            return pair.description != markerDescription
        }

        if !cues.isEmpty,
           let encoded = try? JSONEncoder().encode(cues.sorted { $0.slot < $1.slot }),
           let value = String(data: encoded, encoding: .utf8) {
            let payload = encodeUserTextFrame(description: markerDescription, value: value)
            let sizeBytes = encodeFrameSize(payload.count, versionMajor: version)
            var frameData = Data("TXXX".utf8)
            frameData.append(contentsOf: sizeBytes)
            frameData.append(contentsOf: [0x00, 0x00])
            frameData.append(payload)
            frames.append(ID3Frame(id: "TXXX", payload: payload, rawData: frameData))
        }

        let tagPayload = Data(frames.map(\.rawData).joined())
        let header = makeID3Header(versionMajor: version, payloadSize: tagPayload.count)

        var output = Data()
        output.append(header)
        output.append(tagPayload)
        output.append(audioBody)

        try? AtomicFileWriter.write(output, to: track.fileURL)
    }

    private struct ParsedID3Tag {
        let versionMajor: UInt8
        let frames: [ID3Frame]
        let audioBody: Data
    }

    private struct ID3Frame {
        let id: String
        let payload: Data
        let rawData: Data
    }

    private static func parseID3Tag(from data: Data) -> ParsedID3Tag? {
        guard data.count >= 10 else { return nil }
        guard String(data: data.prefix(3), encoding: .ascii) == "ID3" else { return nil }

        let versionMajor = data[3]
        guard versionMajor == 3 || versionMajor == 4 else { return nil }

        let tagSize = decodeSyncSafeInt(Array(data[6...9]))
        guard tagSize > 0, data.count >= 10 + tagSize else {
            return ParsedID3Tag(versionMajor: versionMajor, frames: [], audioBody: data.subdata(in: min(10, data.count)..<data.count))
        }

        let tagPayload = data.subdata(in: 10..<(10 + tagSize))
        let audioBody = data.subdata(in: (10 + tagSize)..<data.count)

        var frames: [ID3Frame] = []
        var offset = 0

        while offset + 10 <= tagPayload.count {
            let header = tagPayload.subdata(in: offset..<(offset + 10))
            let frameIDData = header.prefix(4)
            guard let frameID = String(data: frameIDData, encoding: .ascii), frameIDData.allSatisfy({ $0 != 0 }) else {
                break
            }

            let sizeBytes = Array(header[4...7])
            let frameSize: Int
            if versionMajor == 4 {
                frameSize = decodeSyncSafeInt(sizeBytes)
            } else {
                frameSize = decodeBigEndianInt(sizeBytes)
            }

            if frameSize <= 0 || offset + 10 + frameSize > tagPayload.count {
                break
            }

            let payload = tagPayload.subdata(in: (offset + 10)..<(offset + 10 + frameSize))
            let raw = tagPayload.subdata(in: offset..<(offset + 10 + frameSize))
            frames.append(ID3Frame(id: frameID, payload: payload, rawData: raw))
            offset += 10 + frameSize
        }

        return ParsedID3Tag(versionMajor: versionMajor, frames: frames, audioBody: audioBody)
    }

    private static func makeID3Header(versionMajor: UInt8, payloadSize: Int) -> Data {
        var header = Data()
        header.append(contentsOf: [0x49, 0x44, 0x33])
        header.append(versionMajor)
        header.append(0x00)
        header.append(0x00)
        header.append(contentsOf: encodeSyncSafeInt(payloadSize))
        return header
    }

    private static func encodeFrameSize(_ value: Int, versionMajor: UInt8) -> [UInt8] {
        if versionMajor == 4 {
            return encodeSyncSafeInt(value)
        }
        return [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }

    private static func encodeSyncSafeInt(_ value: Int) -> [UInt8] {
        let v = max(0, value)
        return [
            UInt8((v >> 21) & 0x7F),
            UInt8((v >> 14) & 0x7F),
            UInt8((v >> 7) & 0x7F),
            UInt8(v & 0x7F)
        ]
    }

    private static func decodeSyncSafeInt(_ bytes: [UInt8]) -> Int {
        guard bytes.count == 4 else { return 0 }
        return (Int(bytes[0] & 0x7F) << 21)
            | (Int(bytes[1] & 0x7F) << 14)
            | (Int(bytes[2] & 0x7F) << 7)
            | Int(bytes[3] & 0x7F)
    }

    private static func decodeBigEndianInt(_ bytes: [UInt8]) -> Int {
        guard bytes.count == 4 else { return 0 }
        return (Int(bytes[0]) << 24)
            | (Int(bytes[1]) << 16)
            | (Int(bytes[2]) << 8)
            | Int(bytes[3])
    }

    private static func encodeUserTextFrame(description: String, value: String) -> Data {
        var payload = Data([0x03])
        payload.append(description.data(using: .utf8) ?? Data())
        payload.append(0x00)
        payload.append(value.data(using: .utf8) ?? Data())
        return payload
    }

    private static func decodeUserTextFrame(_ payload: Data) -> (description: String, value: String) {
        guard !payload.isEmpty else { return ("", "") }
        let encodingByte = payload[0]
        let body = payload.dropFirst()

        // We only write UTF-8 (0x03). For any other encoding, decode best-effort as UTF-8.
        let _ = encodingByte
        let bytes = Array(body)
        guard let sep = bytes.firstIndex(of: 0x00) else {
            return ("", String(decoding: bytes, as: UTF8.self))
        }

        let description = String(decoding: bytes[0..<sep], as: UTF8.self)
        let valueStart = min(sep + 1, bytes.count)
        let value = String(decoding: bytes[valueStart..<bytes.count], as: UTF8.self)
        return (description, value)
    }
}

@MainActor
final class TrackAudioPlayerViewModel: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var errorMessage: String?
    @Published var loadedTrackPath: String?
    @Published var waveform: [CGFloat] = []

    private var player: AVAudioPlayer?

    func load(track: Track) {
        if loadedTrackPath == track.seratoStoredPath {
            return
        }

        isPlaying = false
        loadedTrackPath = nil
        duration = 0
        currentTime = 0
        waveform = []

        guard FileManager.default.fileExists(atPath: track.fileURL.path) else {
            errorMessage = "Track file is missing on disk."
            player = nil
            return
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: track.fileURL)
            newPlayer.prepareToPlay()
            player = newPlayer
            duration = newPlayer.duration
            currentTime = newPlayer.currentTime
            loadedTrackPath = track.seratoStoredPath
            errorMessage = nil
            Task {
                let samples = await Self.computeWaveform(url: track.fileURL, bins: 220)
                await MainActor.run {
                    if self.loadedTrackPath == track.seratoStoredPath {
                        self.waveform = samples
                    }
                }
            }
        } catch {
            player = nil
            errorMessage = "Couldn't load audio: \(error.localizedDescription)"
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        currentTime = player.currentTime
    }

    func seek(to time: Double) {
        guard let player else { return }
        let clamped = max(0, min(time, duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    func jump(by delta: Double) {
        seek(to: currentTime + delta)
    }

    func refreshProgress() {
        guard let player else { return }
        currentTime = player.currentTime
        isPlaying = player.isPlaying
    }

    nonisolated private static func computeWaveform(url: URL, bins: Int) async -> [CGFloat] {
        await Task.detached(priority: .userInitiated) {
            var envelope = Array(repeating: CGFloat(0), count: max(1, bins))
            do {
                let file = try AVAudioFile(forReading: url)
                let totalFrames = max(1, Int(file.length))
                let format = file.processingFormat
                guard let channels = format.channelCount as UInt32? else { return envelope }

                let capacity: AVAudioFrameCount = 4096
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
                    return envelope
                }

                var frameBase = 0
                while true {
                    try file.read(into: buffer, frameCount: capacity)
                    let frameLength = Int(buffer.frameLength)
                    if frameLength <= 0 { break }

                    if let floatData = buffer.floatChannelData {
                        let firstChannel = floatData[0]
                        let stride = max(1, frameLength / 256)
                        for i in Swift.stride(from: 0, to: frameLength, by: stride) {
                            let sample = abs(firstChannel[i])
                            let globalFrame = frameBase + i
                            let bin = min(envelope.count - 1, Int((Double(globalFrame) / Double(totalFrames)) * Double(envelope.count)))
                            let amp = CGFloat(sample)
                            if amp > envelope[bin] {
                                envelope[bin] = amp
                            }
                        }
                    } else if channels > 0, let intData = buffer.int16ChannelData {
                        let firstChannel = intData[0]
                        let stride = max(1, frameLength / 256)
                        for i in Swift.stride(from: 0, to: frameLength, by: stride) {
                            let sample = abs(Double(firstChannel[i])) / Double(Int16.max)
                            let globalFrame = frameBase + i
                            let bin = min(envelope.count - 1, Int((Double(globalFrame) / Double(totalFrames)) * Double(envelope.count)))
                            let amp = CGFloat(sample)
                            if amp > envelope[bin] {
                                envelope[bin] = amp
                            }
                        }
                    }

                    frameBase += frameLength
                }

                let maxValue = envelope.max() ?? 1
                if maxValue > 0 {
                    envelope = envelope.map { max(0.03, $0 / maxValue) }
                }
                return envelope
            } catch {
                return envelope
            }
        }.value
    }
}

struct TrackAudioPlayerPanel: View {
    let track: Track

    @StateObject private var player = TrackAudioPlayerViewModel()
    @State private var cues: [TrackHotCuePoint] = []
    @State private var editingSlot: Int?
    @State private var editingNameDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(track.title.isEmpty ? track.fileURL.lastPathComponent : track.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(formatTime(player.currentTime)) / \(formatTime(player.duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            waveformView
                .frame(height: 56)

            HStack(spacing: 8) {
                Button(player.isPlaying ? "Pause" : "Play") {
                    player.togglePlayPause()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(player.loadedTrackPath == nil)

                Button("-5") { player.jump(by: -5) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(player.loadedTrackPath == nil)

                Button("+5") { player.jump(by: 5) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(player.loadedTrackPath == nil)

                Spacer()

                if let error = player.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(1...8, id: \.self) { slot in
                    compactCueSlot(slot: slot)
                }
            }

            Text("Click pad: set cue at current time  •  Double-click: rename  •  Right-click: color")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            loadTrackAndCues()
        }
        .onChange(of: track.id) {
            loadTrackAndCues()
        }
        .onReceive(Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()) { _ in
            player.refreshProgress()
        }
    }

    private var waveformView: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .windowBackgroundColor),
                                Color.accentColor.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                HStack(alignment: .center, spacing: 1) {
                    ForEach(Array(player.waveform.enumerated()), id: \.offset) { _, amp in
                        Capsule()
                            .fill(Color.accentColor.opacity(0.75))
                            .frame(width: 1.2, height: max(4, geo.size.height * amp))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 4)

                if player.duration > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 2)
                        .offset(x: max(0, min(geo.size.width - 2, (geo.size.width * CGFloat(player.currentTime / player.duration)))))
                }

                if player.duration > 0 {
                    ForEach(cues) { cue in
                        let markerX = max(0, min(geo.size.width - 1, geo.size.width * CGFloat(cue.timeSeconds / player.duration)))
                        Rectangle()
                            .fill(color(forHex: cue.colorHex).opacity(0.95))
                            .frame(width: 1, height: geo.size.height)
                            .offset(x: markerX)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let x = max(0, min(geo.size.width, value.location.x))
                        let ratio = geo.size.width > 0 ? (x / geo.size.width) : 0
                        player.seek(to: player.duration * Double(ratio))
                    }
            )
        }
    }

    @ViewBuilder
    private func compactCueSlot(slot: Int) -> some View {
        let cue = cues.first(where: { $0.slot == slot })
        let cueColor = cue.map { color(forHex: $0.colorHex) } ?? Color.secondary.opacity(0.25)
        let slotLabelColor = cue == nil ? Color.secondary : Color.white.opacity(0.92)
        let cueNameText = cue?.name ?? "—"
        let cueTimeText = cue.map { formatTime($0.timeSeconds) } ?? ""
        let cueNameColor = cue == nil ? Color.secondary : Color.white
        let cueTimeColor = cue == nil ? Color.secondary : Color.white.opacity(0.9)

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text("\(slot)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(slotLabelColor)

                if let cue {
                    Circle()
                        .fill(color(forHex: cue.colorHex))
                        .frame(width: 6, height: 6)
                }

                Spacer(minLength: 0)

                if cue != nil {
                    Button {
                        clearCue(slot: slot)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
            }

            if editingSlot == slot {
                TextField("Name", text: $editingNameDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .onSubmit {
                        commitCueName(slot: slot)
                    }
                    .onDisappear {
                        if editingSlot == slot {
                            commitCueName(slot: slot)
                        }
                    }
            } else {
                Text(cueNameText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(cueNameColor)

                Text(cueTimeText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(cueTimeColor)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .frame(minHeight: 36)
        .background(
            cue == nil
                ? Color(nsColor: .windowBackgroundColor)
                : cueColor.opacity(0.78)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(cue == nil ? Color.secondary.opacity(0.18) : cueColor.opacity(0.9), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            // Single click sets/updates cue at current playhead.
            setCue(slot: slot)
        }
        .onTapGesture(count: 2) {
            if let cue {
                editingSlot = slot
                editingNameDraft = cue.name
            }
        }
        .contextMenu {
            ForEach(Self.hotCuePalette, id: \.hex) { color in
                Button(color.name) {
                    updateCueColor(slot: slot, hex: color.hex)
                }
            }
        }
    }

    private func loadTrackAndCues() {
        player.load(track: track)

        let imported = TrackHotCueMetadataStore.load(for: track)
        if imported.isEmpty {
            cues = TrackHotCueCacheStore.load(for: track)
        } else {
            cues = imported
            TrackHotCueCacheStore.save(imported, for: track)
        }
    }

    private func setCue(slot: Int) {
        guard player.loadedTrackPath != nil else { return }
        let current = max(0, player.currentTime)
        let autoName = formatTime(current)

        if let existingIndex = cues.firstIndex(where: { $0.slot == slot }) {
            cues[existingIndex].timeSeconds = current
            cues[existingIndex].name = autoName
            if cues[existingIndex].colorHex.isEmpty {
                cues[existingIndex].colorHex = Self.hotCuePalette[(slot - 1) % Self.hotCuePalette.count].hex
            }
        } else {
            cues.append(
                TrackHotCuePoint(
                    slot: slot,
                    timeSeconds: current,
                    name: autoName,
                    colorHex: Self.hotCuePalette[(slot - 1) % Self.hotCuePalette.count].hex
                )
            )
        }

        persistCuesRealtime()
    }

    private func clearCue(slot: Int) {
        cues.removeAll { $0.slot == slot }
        if editingSlot == slot {
            editingSlot = nil
            editingNameDraft = ""
        }
        persistCuesRealtime()
    }

    private func commitCueName(slot: Int) {
        defer {
            editingSlot = nil
            editingNameDraft = ""
        }
        guard let index = cues.firstIndex(where: { $0.slot == slot }) else { return }
        let trimmed = editingNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            cues[index].name = formatTime(cues[index].timeSeconds)
        } else {
            cues[index].name = trimmed
        }
        persistCuesRealtime()
    }

    private func updateCueColor(slot: Int, hex: String) {
        if let index = cues.firstIndex(where: { $0.slot == slot }) {
            cues[index].colorHex = hex
            persistCuesRealtime()
        } else {
            setCue(slot: slot)
            if let index = cues.firstIndex(where: { $0.slot == slot }) {
                cues[index].colorHex = hex
                persistCuesRealtime()
            }
        }
    }

    private func persistCuesRealtime() {
        let normalized = cues
            .filter { $0.slot >= 1 && $0.slot <= 8 }
            .sorted { $0.slot < $1.slot }
        cues = normalized

        // Real-time export: write into track metadata (MP3 via ID3 TXXX),
        // and keep app-local cache synchronized for fast fallback reads.
        TrackHotCueMetadataStore.save(normalized, for: track)
        TrackHotCueCacheStore.save(normalized, for: track)
    }

    private func color(forHex hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return .gray
        }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let minutes = total / 60
        let remainder = total % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    private static let hotCuePalette: [(name: String, hex: String)] = [
        ("Red", "FF3B30"),
        ("Orange", "FF9500"),
        ("Yellow", "FFCC00"),
        ("Green", "34C759"),
        ("Mint", "30D158"),
        ("Cyan", "32ADE6"),
        ("Blue", "0A84FF"),
        ("Purple", "BF5AF2")
    ]
}
