import SwiftUI

/// Placeholder illustration of the cat and dog acting out `mood`. Drawn with simple shapes so the
/// feature works end to end; swap the body of this view for real artwork later. Same shapes and
/// colours as the Android `PetScene`.
struct PetScene: View {
    let mood: PetMood

    // The scene is authored on a 260 x 150 grid and scaled to fit.
    private static let sceneWidth: CGFloat = 260
    private static let sceneHeight: CGFloat = 150

    var body: some View {
        Canvas { context, size in
            let painter = Painter(context: context, scale: size.width / Self.sceneWidth)
            painter.sky(mood)
            painter.oval(Palette.ground, cx: 130, cy: 140, rx: 110, ry: 8)
            painter.cat(mood)
            painter.dog(mood)
            painter.props(mood)
        }
        .aspectRatio(Self.sceneWidth / Self.sceneHeight, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("The cat and dog reacting to the weather")
    }
}

private enum Palette {
    static let catFur = Color(hex: 0x5F5E5A)
    static let catBelly = Color(hex: 0xF1EFE8)
    static let dogFur = Color(hex: 0xEF9F27)
    static let dogFace = Color(hex: 0xFAC775)
    static let dogEar = Color(hex: 0xBA7517)
    static let outline = Color(hex: 0x10324A)
    static let umbrella = Color(hex: 0x185FA5)
    static let sun = Color(hex: 0xEF9F27)
    static let sunHot = Color(hex: 0xD85A30)
    static let scarf = Color(hex: 0xD85A30)
    static let scarfAlt = Color(hex: 0x993556)
    static let tongue = Color(hex: 0xD4537E)
    static let cloud = Color.white
    static let stormCloud = Color(hex: 0x5F6B7A)
    static let bolt = Color(hex: 0xFAC775)
    static let moon = Color(hex: 0xF1EFE8)
    static let skyNight = Color(hex: 0x3C4A78)
    static let ground = Color.black.opacity(0.2)
}

/// Draws in scene units, scaling everything by `scale`.
private struct Painter {
    let context: GraphicsContext
    let scale: CGFloat

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }

    func oval(_ color: Color, cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) {
        let rect = CGRect(x: (cx - rx) * scale, y: (cy - ry) * scale, width: rx * 2 * scale, height: ry * 2 * scale)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    func circle(_ color: Color, cx: CGFloat, cy: CGFloat, r: CGFloat) {
        oval(color, cx: cx, cy: cy, rx: r, ry: r)
    }

    func rect(_ color: Color, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        context.fill(Path(CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)), with: .color(color))
    }

    func poly(_ color: Color, _ points: [(CGFloat, CGFloat)]) {
        var path = Path()
        path.addLines(points.map { point($0.0, $0.1) })
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }

    func cloud(_ color: Color, cx: CGFloat, cy: CGFloat) {
        oval(color, cx: cx, cy: cy + 6, rx: 28, ry: 12)
        circle(color, cx: cx - 10, cy: cy, r: 13)
        circle(color, cx: cx + 8, cy: cy - 4, r: 16)
    }

    func sky(_ mood: PetMood) {
        switch mood {
        case .sunny:
            circle(Palette.sun, cx: 220, cy: 32, r: 18)
        case .hot:
            circle(Palette.sunHot, cx: 220, cy: 32, r: 24)
        case .night:
            circle(Palette.moon, cx: 215, cy: 30, r: 16)
            circle(Palette.skyNight, cx: 223, cy: 25, r: 14)
        case .cloudy:
            cloud(Palette.cloud, cx: 210, cy: 30)
        case .rain:
            for (x, y) in [(30, 14), (60, 36), (200, 58), (232, 20), (45, 70), (245, 44)] as [(CGFloat, CGFloat)] {
                rect(Palette.umbrella, x: x, y: y, width: 3, height: 11)
            }
        case .storm:
            cloud(Palette.stormCloud, cx: 200, cy: 28)
            poly(Palette.bolt, [(205, 40), (196, 58), (204, 58), (198, 74), (214, 52), (206, 52), (212, 40)])
        case .snow, .cold:
            for (x, y) in [(30, 18), (70, 44), (200, 22), (240, 50), (110, 12), (180, 40)] as [(CGFloat, CGFloat)] {
                circle(Palette.cloud, cx: x, cy: y, r: 4)
            }
        }
    }

    func cat(_ mood: PetMood) {
        // A storm sends the cat low (hiding); otherwise it sits upright.
        let dy: CGFloat = mood == .storm ? 14 : 0
        oval(Palette.catFur, cx: 95, cy: 112 + dy / 2, rx: 24, ry: 26 - dy / 2)
        circle(Palette.catFur, cx: 95, cy: 80 + dy, r: 20)
        poly(Palette.catFur, [(78, 68 + dy), (82, 50 + dy), (92, 64 + dy)])
        poly(Palette.catFur, [(98, 64 + dy), (108, 50 + dy), (112, 68 + dy)])
        oval(Palette.catBelly, cx: 95, cy: 88 + dy, rx: 11, ry: 8)
        oval(Palette.catBelly, cx: 95, cy: 118 + dy / 2, rx: 12, ry: 14 - dy / 3)
        eyes(mood, left: 88, right: 102, y: 78 + dy)
    }

    func dog(_ mood: PetMood) {
        oval(Palette.dogFur, cx: 160, cy: 110, rx: 28, ry: 28)
        circle(Palette.dogFace, cx: 160, cy: 76, r: 23)
        oval(Palette.dogEar, cx: 139, cy: 80, rx: 8, ry: 15)
        oval(Palette.dogEar, cx: 181, cy: 80, rx: 8, ry: 15)
        eyes(mood, left: 152, right: 168, y: 72)
        oval(Palette.outline, cx: 160, cy: 82, rx: 5, ry: 3.5)
        if mood == .hot {
            oval(Palette.tongue, cx: 160, cy: 94, rx: 4, ry: 7)
        } else {
            var smile = Path()
            smile.move(to: point(154, 88))
            smile.addQuadCurve(to: point(166, 88), control: point(160, 94))
            context.stroke(smile, with: .color(Palette.outline), lineWidth: 2 * scale)
        }
    }

    /// Open eyes, or closed lines when the pets are asleep at night.
    private func eyes(_ mood: PetMood, left: CGFloat, right: CGFloat, y: CGFloat) {
        for x in [left, right] {
            if mood == .night {
                var line = Path()
                line.move(to: point(x - 3, y))
                line.addLine(to: point(x + 3, y))
                context.stroke(line, with: .color(Palette.outline), lineWidth: 2 * scale)
            } else {
                circle(Palette.outline, cx: x, cy: y, r: 2.6)
            }
        }
    }

    func props(_ mood: PetMood) {
        switch mood {
        case .rain:
            var canopy = Path()
            canopy.move(to: point(70, 56))
            canopy.addQuadCurve(to: point(190, 56), control: point(128, 0))
            canopy.closeSubpath()
            context.fill(canopy, with: .color(Palette.umbrella))
            rect(Palette.outline, x: 128, y: 54, width: 3, height: 42)
        case .sunny:
            // Sunglasses on the dog.
            rect(Palette.outline, x: 146, y: 68, width: 12, height: 7)
            rect(Palette.outline, x: 162, y: 68, width: 12, height: 7)
            rect(Palette.outline, x: 157, y: 70, width: 6, height: 2)
        case .snow, .cold:
            rect(Palette.scarf, x: 136, y: 94, width: 48, height: 9)
            rect(Palette.scarfAlt, x: 72, y: 96, width: 46, height: 8)
        default:
            break
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(PetMood.allCases, id: \.self) { mood in
                PetScene(mood: mood)
                    .padding()
                    .background(mood.skyColor, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}
