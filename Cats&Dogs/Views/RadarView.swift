import SwiftUI

private let radarZoom = 10
private let tilePixelSize = 256

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

private struct RadarMapView: View {
    let latitude: Double
    let longitude: Double

    @State private var mapImage: CGImage?
    @State private var overlayImage: CGImage?
    @State private var animationFrame = 0

    private var tileInfo: TileInfo {
        TileInfo.from(latitude: latitude, longitude: longitude, zoom: radarZoom)
    }

    private var layerType: String {
        animationFrame % 2 == 0 ? "clouds" : "precipitation"
    }

    var body: some View {
        Canvas { context, size in
            let bitmapTotal = CGFloat(3 * tilePixelSize)
            let tileDisplay = max(size.width, size.height) / 2
            let scale = tileDisplay / CGFloat(tilePixelSize)
            let locationX = (1 + tileInfo.subFractionX) * CGFloat(tilePixelSize)
            let locationY = (1 + tileInfo.subFractionY) * CGFloat(tilePixelSize)
            let offsetX = size.width / 2 - locationX * scale
            let offsetY = size.height / 2 - locationY * scale
            let drawSize = CGSize(width: bitmapTotal * scale, height: bitmapTotal * scale)
            let drawOrigin = CGPoint(x: offsetX, y: offsetY)

            if let mapImage {
                context.draw(Image(decorative: mapImage, scale: 1), in: CGRect(origin: drawOrigin, size: drawSize))
            }
            if let overlayImage {
                context.opacity = 0.7
                context.draw(Image(decorative: overlayImage, scale: 1), in: CGRect(origin: drawOrigin, size: drawSize))
            }
        }
        .task(id: tileInfo) {
            mapImage = await MapTileLoader.stitchTiles(tileInfo: tileInfo) { x, y in
                "https://tile.openstreetmap.org/\(radarZoom)/\(x)/\(y).png"
            }
        }
        .task(id: "\(tileInfo)-\(layerType)") {
            let apiKey = AppConfig.openWeatherApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            overlayImage = await MapTileLoader.stitchTiles(tileInfo: tileInfo) { x, y in
                "https://tile.openweathermap.org/map/\(layerType)/\(radarZoom)/\(x)/\(y).png?appid=\(apiKey)"
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                animationFrame = (animationFrame + 1) % 4
            }
        }
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
    static func stitchTiles(tileInfo: TileInfo, urlBuilder: (Int, Int) -> String) async -> CGImage? {
        let size = 3 * tilePixelSize
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        var loadedAny = false
        for row in -1...1 {
            for col in -1...1 {
                let x = tileInfo.tileX + col
                let y = tileInfo.tileY + row
                guard let image = await loadTile(from: urlBuilder(x, y)) else { continue }
                loadedAny = true
                // CGContext's origin is bottom-left, so the northern row (-1) goes at the top.
                context.draw(image, in: CGRect(
                    x: (col + 1) * tilePixelSize,
                    y: (1 - row) * tilePixelSize,
                    width: tilePixelSize,
                    height: tilePixelSize
                ))
            }
        }
        return loadedAny ? context.makeImage() : nil
    }

    private static func loadTile(from urlString: String) async -> CGImage? {
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
