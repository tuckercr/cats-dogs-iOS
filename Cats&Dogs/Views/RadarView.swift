import SwiftUI

private enum RadarTiles {
    nonisolated static let zoom = 10
    nonisolated static let pixelSize = 256
}

private let overlayRefreshInterval: Duration = .seconds(600)

struct RadarCard: View {
    let location: SavedLocation?

    var body: some View {
        Group {
            if location == nil {
                placeholder("No location selected")
            } else if location?.latitude == nil || location?.longitude == nil {
                placeholder("Radar unavailable\n(coordinates not available)")
            } else if let location, let latitude = location.latitude, let longitude = location.longitude {
                RadarMapView(latitude: latitude, longitude: longitude)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum RadarLayer: String, CaseIterable {
    case clouds
    case precipitation
}

private struct RadarMapView: View {
    let latitude: Double
    let longitude: Double

    @State private var mapImage: CGImage?
    @State private var overlayImages: [RadarLayer: CGImage] = [:]
    @State private var visibleLayer: RadarLayer = .clouds

    private var tileInfo: TileInfo {
        TileInfo.from(latitude: latitude, longitude: longitude, zoom: RadarTiles.zoom)
    }

    var body: some View {
        Canvas { context, size in
            let bitmapTotal = CGFloat(3 * RadarTiles.pixelSize)
            let tileDisplay = max(size.width, size.height) / 2
            let scale = tileDisplay / CGFloat(RadarTiles.pixelSize)
            let locationX = (1 + tileInfo.subFractionX) * CGFloat(RadarTiles.pixelSize)
            let locationY = (1 + tileInfo.subFractionY) * CGFloat(RadarTiles.pixelSize)
            let offsetX = size.width / 2 - locationX * scale
            let offsetY = size.height / 2 - locationY * scale
            let drawSize = CGSize(width: bitmapTotal * scale, height: bitmapTotal * scale)
            let drawOrigin = CGPoint(x: offsetX, y: offsetY)

            if let mapImage {
                context.draw(Image(decorative: mapImage, scale: 1), in: CGRect(origin: drawOrigin, size: drawSize))
            }
            if let overlayImage = overlayImages[visibleLayer] {
                context.opacity = 0.7
                context.draw(Image(decorative: overlayImage, scale: 1), in: CGRect(origin: drawOrigin, size: drawSize))
            }
        }
        .task(id: tileInfo) {
            let tile = tileInfo
            mapImage = nil
            let image = await MapTileLoader.stitchTiles(tileX: tile.tileX, tileY: tile.tileY) { x, y in
                "https://tile.openstreetmap.org/\(RadarTiles.zoom)/\(x)/\(y).png"
            }
            guard !Task.isCancelled else { return }
            mapImage = image
        }
        // Each layer is fetched once per location (then every `overlayRefreshInterval`), never per
        // animation frame: the frame timer below only switches which loaded image is drawn.
        .task(id: tileInfo) {
            let tile = tileInfo
            let apiKey = AppConfig.openWeatherApiKey
            overlayImages = [:]
            while !Task.isCancelled {
                await withTaskGroup(of: Void.self) { group in
                    for layer in RadarLayer.allCases {
                        group.addTask {
                            let image = await MapTileLoader.stitchTiles(tileX: tile.tileX, tileY: tile.tileY) { x, y in
                                "https://tile.openweathermap.org/map/\(layer.rawValue)/\(RadarTiles.zoom)/\(x)/\(y).png?appid=\(apiKey)"
                            }
                            guard !Task.isCancelled, let image else { return }
                            await setOverlay(image, for: layer)
                        }
                    }
                }
                try? await Task.sleep(for: overlayRefreshInterval)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                visibleLayer = visibleLayer == .clouds ? .precipitation : .clouds
            }
        }
    }

    private func setOverlay(_ image: CGImage, for layer: RadarLayer) {
        overlayImages[layer] = image
    }
}

private struct TileInfo: Equatable {
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
    /// Returns nil when nothing loaded or the task was cancelled, so a cancelled load never yields a
    /// half-drawn mosaic.
    nonisolated static func stitchTiles(
        tileX: Int,
        tileY: Int,
        urlBuilder: @escaping @Sendable (Int, Int) -> String
    ) async -> CGImage? {
        let tiles = await withTaskGroup(of: (col: Int, row: Int, image: CGImage?).self) { group in
            for row in -1...1 {
                for col in -1...1 {
                    group.addTask {
                        (col, row, await loadTile(from: urlBuilder(tileX + col, tileY + row)))
                    }
                }
            }
            var loaded: [(col: Int, row: Int, image: CGImage)] = []
            for await tile in group {
                if let image = tile.image {
                    loaded.append((tile.col, tile.row, image))
                }
            }
            return loaded
        }
        guard !Task.isCancelled, !tiles.isEmpty else { return nil }

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

        for tile in tiles {
            // CGContext's origin is bottom-left, so the northern row (-1) goes at the top.
            context.draw(tile.image, in: CGRect(
                x: (tile.col + 1) * RadarTiles.pixelSize,
                y: (1 - tile.row) * RadarTiles.pixelSize,
                width: RadarTiles.pixelSize,
                height: RadarTiles.pixelSize
            ))
        }
        return context.makeImage()
    }

    private nonisolated static func loadTile(from urlString: String) async -> CGImage? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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
