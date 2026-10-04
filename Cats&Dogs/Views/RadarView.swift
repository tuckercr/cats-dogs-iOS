import SwiftUI

private enum RadarTiles {
    // RainViewer only serves radar tiles up to zoom 7; regional zoom suits precipitation radar.
    nonisolated static let zoom = RadarTimeline.maxZoom
    nonisolated static let pixelSize = 256
    /// Radar frames stitched at once; each one fetches 9 tiles.
    static let concurrentFrames = 4
    /// Waits before retrying the tiles that failed, so a network blip doesn't leave gaps for good.
    nonisolated static let retryDelays: [Duration] = [.seconds(1), .seconds(2), .seconds(4)]
}

/// Radar precipitation legend, light (low intensity) to heavy (high intensity).
private let radarLegendColors: [Color] = [
    Color(red: 0x8C / 255, green: 0xD9 / 255, blue: 0xFF / 255),
    Color(red: 0x2E / 255, green: 0x9B / 255, blue: 0xE6 / 255),
    Color(red: 0x39 / 255, green: 0xC2 / 255, blue: 0x4A / 255),
    Color(red: 0xF4 / 255, green: 0xE0 / 255, blue: 0x4D / 255),
    Color(red: 0xF3 / 255, green: 0x9B / 255, blue: 0x2E / 255),
    Color(red: 0xE2 / 255, green: 0x4B / 255, blue: 0x4B / 255),
]

struct RadarCard: View {
    let location: SavedLocation?
    /// The city's time zone, so frame times read on its clock rather than the device's.
    var timeZone: TimeZone = .current

    var body: some View {
        Group {
            if let location, let latitude = location.latitude, let longitude = location.longitude {
                RadarMapView(latitude: latitude, longitude: longitude, timeZone: timeZone)
            } else if location == nil {
                placeholder("No location selected")
            } else {
                placeholder("Radar unavailable\n(coordinates not available)")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
        .background(Color.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// An OpenStreetMap base map with RainViewer's radar frames animated over it.
private struct RadarMapView: View {
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone

    private let radar = RadarViewModel.shared

    @State private var baseMap: CGImage?
    /// Stitched radar overlays keyed by frame path, kept so replays are smooth.
    @State private var overlays: [String: CGImage] = [:]
    @State private var frameIndex = 0
    @State private var playing = true

    private var tileInfo: TileInfo {
        TileInfo.from(latitude: latitude, longitude: longitude, zoom: RadarTiles.zoom)
    }

    private var timeline: RadarTimeline? { radar.timeline.successValue }
    private var frames: [RadarFrame] { timeline?.frames ?? [] }
    /// The most recent observed frame: "now".
    private var nowIndex: Int { frames.lastIndex { !$0.isForecast } ?? 0 }

    var body: some View {
        ZStack {
            RadarCanvas(
                tileInfo: tileInfo,
                baseMap: baseMap,
                overlay: frames.indices.contains(frameIndex) ? overlays[frames[frameIndex].path] : nil
            )

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    if frames.indices.contains(frameIndex) {
                        OverlayChip {
                            Text(frameLabel(frames[frameIndex], isNow: frameIndex == nowIndex))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    Spacer()
                    RadarLegend()
                }
                Spacer()
                bottomBar
            }
            .padding(8)
        }
        .task { radar.load() }
        .task(id: tileInfo) {
            let tile = tileInfo
            baseMap = nil
            let image = await MapTileLoader.stitchTiles(tileX: tile.tileX, tileY: tile.tileY) { x, y in
                "https://tile.openstreetmap.org/\(RadarTiles.zoom)/\(x)/\(y).png"
            }
            guard !Task.isCancelled else { return }
            baseMap = image
        }
        // Prefetch every frame's overlay once per location and timeline, keyed on those rather than
        // the current frame, so autoplay never cancels a load. Frames nearest "now" load first.
        .task(id: OverlayKey(tile: tileInfo, timeline: timeline)) {
            overlays = [:]
            frameIndex = nowIndex
            playing = true
            guard let timeline else { return }
            let tile = tileInfo
            let now = nowIndex
            let order = timeline.frames.indices.sorted { abs($0 - now) < abs($1 - now) }.map { timeline.frames[$0] }
            await withTaskGroup(of: (path: String, image: CGImage?).self) { group in
                var pending = order.makeIterator()
                func startNext() {
                    guard let frame = pending.next() else { return }
                    group.addTask {
                        let image = await MapTileLoader.stitchTiles(tileX: tile.tileX, tileY: tile.tileY) { x, y in
                            timeline.tileURL(for: frame, z: RadarTiles.zoom, x: x, y: y)
                        }
                        return (frame.path, image)
                    }
                }
                for _ in 0 ..< RadarTiles.concurrentFrames { startNext() }
                for await result in group {
                    guard !Task.isCancelled else { return }
                    if let image = result.image { overlays[result.path] = image }
                    startNext()
                }
            }
        }
        .task(id: PlaybackKey(playing: playing, frameCount: frames.count)) {
            guard playing, !frames.isEmpty else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: RadarViewModel.frameInterval)
                guard !Task.isCancelled, !frames.isEmpty else { return }
                frameIndex = (frameIndex + 1) % frames.count
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch radar.timeline {
        case .success:
            HStack(spacing: 4) {
                Button {
                    playing.toggle()
                } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(playing ? "Pause radar animation" : "Play radar animation")
                Slider(
                    value: Binding(
                        get: { Double(frameIndex) },
                        set: { value in
                            playing = false
                            frameIndex = min(max(Int(value.rounded()), 0), max(frames.count - 1, 0))
                        }
                    ),
                    in: 0 ... Double(max(frames.count - 1, 1)),
                    step: 1
                )
                .padding(.trailing, 8)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.brandSurface.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        case .error:
            OverlayChip {
                HStack(spacing: 8) {
                    Text("Radar unavailable")
                        .font(.caption)
                    Button("Retry") { radar.retry() }
                        .font(.caption)
                }
            }
        case .idle, .loading:
            OverlayChip {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading radar…")
                        .font(.caption)
                }
            }
        }
    }

    /// "Now · 7:50 AM" for the latest observed frame, "Forecast · …" for nowcast frames.
    private func frameLabel(_ frame: RadarFrame, isNow: Bool) -> String {
        let time = WeatherFormatting.epochTime(frame.timeEpochSeconds, timeZone: timeZone)
        if isNow { return "Now · \(time)" }
        if frame.isForecast { return "Forecast · \(time)" }
        return time
    }
}

private struct OverlayKey: Equatable {
    let tile: TileInfo
    let timeline: RadarTimeline?
}

private struct PlaybackKey: Equatable {
    let playing: Bool
    let frameCount: Int
}

private struct RadarCanvas: View {
    let tileInfo: TileInfo
    let baseMap: CGImage?
    let overlay: CGImage?

    var body: some View {
        Canvas { context, size in
            let bitmapTotal = CGFloat(3 * RadarTiles.pixelSize)
            let tileDisplay = max(size.width, size.height) / 2
            let scale = tileDisplay / CGFloat(RadarTiles.pixelSize)
            let locationX = (1 + tileInfo.subFractionX) * CGFloat(RadarTiles.pixelSize)
            let locationY = (1 + tileInfo.subFractionY) * CGFloat(RadarTiles.pixelSize)
            let rect = CGRect(
                x: size.width / 2 - locationX * scale,
                y: size.height / 2 - locationY * scale,
                width: bitmapTotal * scale,
                height: bitmapTotal * scale
            )
            if let baseMap {
                context.draw(Image(decorative: baseMap, scale: 1), in: rect)
            }
            if let overlay {
                context.opacity = 0.8
                context.draw(Image(decorative: overlay, scale: 1), in: rect)
            }
        }
    }
}

private struct OverlayChip<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.brandSurface.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RadarLegend: View {
    var body: some View {
        VStack(spacing: 2) {
            LinearGradient(colors: radarLegendColors, startPoint: .leading, endPoint: .trailing)
                .frame(width: 96, height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            HStack {
                Text("Light")
                Spacer()
                Text("Heavy")
            }
            .font(.caption2)
            .frame(width: 96)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.brandSurface.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TileInfo: Hashable {
    let tileX: Int
    let tileY: Int
    let subFractionX: Double
    let subFractionY: Double

    static func from(latitude: Double, longitude: Double, zoom: Int) -> TileInfo {
        let n = pow(2.0, Double(zoom))
        let exactX = (longitude + 180.0) / 360.0 * n
        let latRad = latitude * .pi / 180.0
        let exactY = (1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / .pi) / 2.0 * n
        let tileX = Int(exactX)
        let tileY = Int(exactY)
        return TileInfo(
            tileX: tileX,
            tileY: tileY,
            subFractionX: exactX - Double(tileX),
            subFractionY: exactY - Double(tileY)
        )
    }
}

private enum MapTileLoader {
    /// Loads the 3×3 block of tiles around (`tileX`, `tileY`) concurrently and stitches them together.
    /// Tiles that fail are retried, only those, after each of `RadarTiles.retryDelays`; after the
    /// last try a partial image is still better than none. Returns nil when nothing loaded or the
    /// task was cancelled, so a cancelled load never yields a half-drawn mosaic.
    nonisolated static func stitchTiles(
        tileX: Int,
        tileY: Int,
        urlBuilder: @escaping @Sendable (Int, Int) -> String
    ) async -> CGImage? {
        // Tiles are numbered 0...8, row by row from the north-west corner.
        var loaded: [Int: CGImage] = [:]
        let all = Array(0 ..< 9)
        for attempt in 0 ... RadarTiles.retryDelays.count {
            if attempt > 0 {
                try? await Task.sleep(for: RadarTiles.retryDelays[attempt - 1])
            }
            guard !Task.isCancelled else { return nil }
            let missing = all.filter { loaded[$0] == nil }
            let fetched = await withTaskGroup(of: (Int, CGImage?).self) { group in
                for slot in missing {
                    group.addTask {
                        (slot, await loadTile(from: urlBuilder(tileX + slot % 3 - 1, tileY + slot / 3 - 1)))
                    }
                }
                var results: [(Int, CGImage?)] = []
                for await result in group { results.append(result) }
                return results
            }
            for case let (slot, image?) in fetched { loaded[slot] = image }
            if loaded.count == all.count { break }
        }
        guard !Task.isCancelled, !loaded.isEmpty else { return nil }

        let size = 3 * RadarTiles.pixelSize
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        for (slot, image) in loaded {
            // CGContext's origin is bottom-left, so the northern row (slot 0...2) goes at the top.
            context.draw(image, in: CGRect(
                x: (slot % 3) * RadarTiles.pixelSize,
                y: (2 - slot / 3) * RadarTiles.pixelSize,
                width: RadarTiles.pixelSize,
                height: RadarTiles.pixelSize
            ))
        }
        return context.makeImage()
    }

    private nonisolated static func loadTile(from urlString: String) async -> CGImage? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                return nil
            }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        } catch {
            return nil
        }
    }
}

#Preview {
    RadarCard(
        location: SavedLocation(label: "London", latitude: 51.5074, longitude: -0.1278)
    )
    .padding()
}
