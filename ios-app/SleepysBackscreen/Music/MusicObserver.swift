import Foundation
import MediaPlayer
import UIKit

class MusicObserver: NSObject {
    static let shared = MusicObserver()

    private let player = MPMusicPlayerController.systemMusicPlayer
    var onTrackChanged: ((String, String, String, Double, Double, Bool, String?) -> Void)?

    override init() {
        super.init()
        setupObserver()
    }

    func setupObserver() {
        // Request media library permission
        MPMediaLibrary.requestAuthorization { status in
            if status == .authorized {
                DispatchQueue.main.async {
                    self.startObserving()
                    self.fetchCurrentTrack()
                }
            }
        }
    }

    func startObserving() {
        player.beginGeneratingPlaybackNotifications()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTrackChange),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackChange),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player
        )
    }

    @objc private func handleTrackChange() {
        fetchCurrentTrack()
    }

    @objc private func handlePlaybackChange() {
        let isPlaying = player.playbackState == .playing
        let position = player.currentPlaybackTime
        BLEManager.shared.sendPlaybackState(position: Int64(position), isPlaying: isPlaying)
    }

    func fetchCurrentTrack() {
        guard let item = player.nowPlayingItem else { return }

        let title = item.title ?? "Unknown Track"
        let artist = item.artist ?? "Unknown Artist"
        let album = item.albumTitle ?? ""
        let duration = item.playbackDuration
        let position = player.currentPlaybackTime
        let isPlaying = player.playbackState == .playing

        var artworkImage: UIImage?
        var artworkDataUrl: String?

        if let artwork = item.artwork {
            artworkImage = artwork.image(at: CGSize(width: 80, height: 80))
            if let image = artworkImage, let pngData = image.pngData() {
                artworkDataUrl = "data:image/png;base64," + pngData.base64EncodedString()
            }
        }

        // Notify Web View
        onTrackChanged?(title, artist, album, duration, position, isPlaying, artworkDataUrl)

        // Send to ESP32 Display via BLE
        BLEManager.shared.sendMetadata(
            title: title,
            artist: artist,
            album: album,
            duration: Int64(duration),
            artwork: artworkImage
        )
    }

    deinit {
        player.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
    }
}
