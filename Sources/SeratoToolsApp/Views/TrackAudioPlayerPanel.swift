import SwiftUI
import AppKit
import AVFoundation
import SeratoToolsCore

@MainActor
final class TrackAudioPlayerViewModel: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var duration: Double = 0
    @Published var currentTime: Double = 0
    @Published var errorMessage: String?
    @Published var loadedTrackPath: String?

    private var player: AVAudioPlayer?

    func load(track: Track) {
        if loadedTrackPath == track.seratoStoredPath {
            return
        }

        isPlaying = false
        loadedTrackPath = nil
        duration = 0
        currentTime = 0

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
        } catch {
            player = nil
            errorMessage = "Couldn't load audio: \(error.localizedDescription)"
        }
    }

    func startPlayback() {
        guard let player else { return }
        player.play()
        isPlaying = true
        currentTime = player.currentTime
    }

    func stopPlayback() {
        guard let player else { return }
        player.pause()
        player.currentTime = 0
        isPlaying = false
        currentTime = 0
    }

    func handleSpacebarToggle() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    func seek(to time: Double) {
        guard let player else { return }
        let clamped = max(0, min(time, duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    func refreshProgress() {
        guard let player else { return }
        currentTime = player.currentTime
        isPlaying = player.isPlaying
    }
}

struct TrackAudioPlayerPanel: View {
    let track: Track

    @StateObject private var player = TrackAudioPlayerViewModel()
    @State private var keyMonitor: Any?
    @FocusState private var isPanelFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(track.title.isEmpty ? track.fileURL.lastPathComponent : track.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(formatTime(player.currentTime)) / \(formatTime(player.duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 1)
            )
            .disabled(player.loadedTrackPath == nil)

            HStack(spacing: 8) {
                Button("Start") {
                    player.startPlayback()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(player.loadedTrackPath == nil)

                Button("Stop") {
                    player.stopPlayback()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(player.loadedTrackPath == nil)

                Spacer()

                Text("Space: Start/Stop")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let error = player.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .focusable(true)
        .focused($isPanelFocused)
        .simultaneousGesture(
            TapGesture().onEnded {
                isPanelFocused = true
            }
        )
        .onAppear {
            player.load(track: track)
            installKeyboardMonitor()
            isPanelFocused = true
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onChange(of: track.id) {
            player.load(track: track)
            isPanelFocused = true
        }
        .onReceive(Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()) { _ in
            player.refreshProgress()
        }
    }

    private func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            guard isPanelFocused else {
                return event
            }

            if !event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                return event
            }

            // Spacebar key code on macOS.
            if event.keyCode == 49 {
                player.handleSpacebarToggle()
                return nil
            }

            return event
        }
    }

    private func removeKeyboardMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let minutes = total / 60
        let remainder = total % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}
