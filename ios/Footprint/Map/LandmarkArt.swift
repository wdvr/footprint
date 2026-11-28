import MapKit
import SwiftUI

/// Cartoon 2.5D landmark: an outlined front silhouette extruded up and to the right in a darker
/// shade, standing on a soft ground shadow. Drawn on a 100×100 grid.
struct LandmarkArt: View {
    let style: Landmark.Style

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 100, y: size.height / 100)
            LandmarkDrawing.draw(style, in: &context)
        }
        .accessibilityHidden(true)
    }
}

enum LandmarkDrawing {

    private static let ink = Color(red: 0.23, green: 0.16, blue: 0.13)

    private static func palette(_ style: Landmark.Style) -> (front: Color, side: Color) {
        switch style {
        case .latticeTower: (Color(red: 0.76, green: 0.52, blue: 0.34), Color(red: 0.50, green: 0.32, blue: 0.19))
        case .statue: (Color(red: 0.52, green: 0.80, blue: 0.67), Color(red: 0.31, green: 0.58, blue: 0.47))
        case .pyramid, .peak, .wall, .arena, .gate: (Color(red: 0.93, green: 0.79, blue: 0.50), Color(red: 0.72, green: 0.57, blue: 0.30))
        case .bridge: (Color(red: 0.91, green: 0.36, blue: 0.22), Color(red: 0.64, green: 0.22, blue: 0.12))
        case .pagoda: (Color(red: 0.88, green: 0.30, blue: 0.27), Color(red: 0.60, green: 0.16, blue: 0.15))
        case .spire, .atomium: (Color(red: 0.80, green: 0.85, blue: 0.92), Color(red: 0.52, green: 0.58, blue: 0.68))
        case .windmill: (Color(red: 0.97, green: 0.62, blue: 0.30), Color(red: 0.72, green: 0.40, blue: 0.16))
        case .clockTower, .dome, .temple, .sails: (Color(red: 0.97, green: 0.95, blue: 0.90), Color(red: 0.78, green: 0.74, blue: 0.67))
        }
    }

    static func draw(_ style: Landmark.Style, in context: inout GraphicsContext) {
        context.fill(Path(ellipseIn: CGRect(x: 14, y: 87, width: 76, height: 10)), with: .color(.black.opacity(0.22)))
        let (front, side) = palette(style)
        let body = silhouette(style)
        context.fill(body.offsetBy(dx: 5, dy: -3), with: .color(side), style: FillStyle(eoFill: true))
        context.stroke(body.offsetBy(dx: 5, dy: -3), with: .color(ink), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        context.fill(body, with: .color(front), style: FillStyle(eoFill: true))
        context.stroke(body, with: .color(ink), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        details(style, in: &context)
    }

    private static func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
        path.closeSubpath()
        return path
    }

    private static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
        Path(CGRect(x: x, y: y, width: w, height: h))
    }

    private static func silhouette(_ style: Landmark.Style) -> Path {
        switch style {
        case .latticeTower:
            return polygon([(18, 90), (34, 90), (43, 72), (57, 72), (66, 90), (82, 90), (62, 54), (55, 22), (51, 4),
                            (49, 4), (45, 22), (38, 54)])
        case .clockTower:
            var path = rect(39, 30, 22, 60)
            path.addPath(polygon([(37, 30), (50, 6), (63, 30)]))
            return path
        case .statue:
            var path = rect(35, 70, 30, 20)
            path.addPath(polygon([(43, 70), (45, 36), (55, 36), (57, 70)]))
            path.addEllipse(in: CGRect(x: 44, y: 24, width: 12, height: 12))
            path.addPath(rect(54, 10, 5, 22))
            return path
        case .pyramid:
            return polygon([(12, 90), (50, 18), (88, 90)])
        case .dome:
            var path = rect(24, 60, 52, 30)
            path.move(to: CGPoint(x: 28, y: 60))
            path.addCurve(to: CGPoint(x: 50, y: 18), control1: CGPoint(x: 22, y: 40), control2: CGPoint(x: 40, y: 26))
            path.addCurve(to: CGPoint(x: 72, y: 60), control1: CGPoint(x: 60, y: 26), control2: CGPoint(x: 78, y: 40))
            path.closeSubpath()
            path.addPath(rect(14, 38, 7, 52))
            path.addPath(rect(79, 38, 7, 52))
            return path
        case .pagoda:
            var path = Path()
            for (i, width) in [CGFloat(64), 50, 36].enumerated() {
                let top = 90 - CGFloat(i + 1) * 22
                path.addPath(rect(50 - width / 2 + 6, top + 8, width - 12, 14))
                path.addPath(polygon([(50 - width / 2 - 4, top + 8), (50 - width / 2 + 6, top), (50 + width / 2 - 6, top),
                                      (50 + width / 2 + 4, top + 8)]))
            }
            path.addPath(rect(48, 10, 4, 14))
            return path
        case .sails:
            var path = rect(8, 80, 84, 10)
            for (x, h) in [(CGFloat(16), CGFloat(40)), (40, 52), (62, 38)] {
                path.move(to: CGPoint(x: x, y: 80))
                path.addQuadCurve(to: CGPoint(x: x + 22, y: 80 - h), control: CGPoint(x: x + 2, y: 80 - h * 0.7))
                path.addLine(to: CGPoint(x: x + 22, y: 80))
                path.closeSubpath()
            }
            return path
        case .arena:
            var path = Path()
            path.move(to: CGPoint(x: 12, y: 90))
            path.addLine(to: CGPoint(x: 12, y: 46))
            path.addQuadCurve(to: CGPoint(x: 88, y: 46), control: CGPoint(x: 50, y: 34))
            path.addLine(to: CGPoint(x: 88, y: 90))
            path.closeSubpath()
            return path
        case .gate:
            var path = rect(18, 28, 64, 62)
            path.addRoundedRect(in: CGRect(x: 38, y: 52, width: 24, height: 38), cornerSize: CGSize(width: 12, height: 12))
            return path
        case .peak:
            return polygon([(6, 90), (38, 34), (50, 22), (62, 34), (94, 90)])
        case .wall:
            var points: [(CGFloat, CGFloat)] = [(6, 90), (6, 52)]
            var x: CGFloat = 6
            while x < 94 {
                points += [(x, 46), (x + 6, 46), (x + 6, 52), (min(x + 11, 94), 52)]
                x += 11
            }
            points += [(94, 52), (94, 90)]
            var path = polygon(points)
            path.addPath(rect(42, 30, 16, 22))
            return path
        case .bridge:
            var path = rect(24, 18, 9, 72)
            path.addPath(rect(67, 18, 9, 72))
            path.addPath(rect(4, 60, 92, 8))
            return path
        case .temple:
            var path = polygon([(14, 34), (50, 14), (86, 34)])
            path.addPath(rect(16, 34, 68, 8))
            for i in 0..<5 { path.addPath(rect(20 + CGFloat(i) * 13, 42, 7, 40)) }
            path.addPath(rect(12, 82, 76, 8))
            return path
        case .windmill:
            var path = polygon([(38, 90), (43, 42), (57, 42), (62, 90)])
            path.addPath(polygon([(41, 42), (50, 30), (59, 42)]))
            return path
        case .spire:
            var path = polygon([(43, 90), (47, 34), (49, 4), (51, 4), (53, 34), (57, 90)])
            path.addEllipse(in: CGRect(x: 41, y: 30, width: 18, height: 10))
            return path
        case .atomium:
            var path = Path()
            for (x, y) in atomiumNodes { path.addEllipse(in: CGRect(x: x - 8, y: y - 8, width: 16, height: 16)) }
            return path
        }
    }

    private static let atomiumNodes: [(CGFloat, CGFloat)] = [
        (50, 14), (26, 32), (74, 32), (50, 48), (26, 64), (74, 64), (50, 80),
    ]

    private static func details(_ style: Landmark.Style, in context: inout GraphicsContext) {
        let line = StrokeStyle(lineWidth: 2, lineCap: .round)
        switch style {
        case .latticeTower:
            for y in [CGFloat(54), 34] {
                var p = Path(); p.move(to: CGPoint(x: 38 + (54 - y) * 0.12, y: y)); p.addLine(to: CGPoint(x: 62 - (54 - y) * 0.12, y: y))
                context.stroke(p, with: .color(ink), style: line)
            }
        case .clockTower:
            context.fill(Path(ellipseIn: CGRect(x: 43, y: 35, width: 14, height: 14)), with: .color(.white))
            context.stroke(Path(ellipseIn: CGRect(x: 43, y: 35, width: 14, height: 14)), with: .color(ink), style: line)
        case .statue:
            context.fill(Path(ellipseIn: CGRect(x: 52, y: 3, width: 9, height: 9)), with: .color(.yellow))
        case .peak:
            context.fill(polygon([(38, 34), (50, 22), (62, 34), (56, 40), (50, 34), (44, 40)]), with: .color(.white))
        case .arena:
            for row in 0..<2 {
                for i in 0..<5 {
                    let r = CGRect(x: 18 + CGFloat(i) * 14, y: 56 + CGFloat(row) * 16, width: 8, height: 11)
                    context.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(ink.opacity(0.55)))
                }
            }
        case .bridge:
            var cable = Path()
            cable.move(to: CGPoint(x: 4, y: 40)); cable.addQuadCurve(to: CGPoint(x: 28, y: 20), control: CGPoint(x: 18, y: 36))
            cable.move(to: CGPoint(x: 28, y: 20)); cable.addQuadCurve(to: CGPoint(x: 72, y: 20), control: CGPoint(x: 50, y: 66))
            cable.move(to: CGPoint(x: 72, y: 20)); cable.addQuadCurve(to: CGPoint(x: 96, y: 40), control: CGPoint(x: 82, y: 36))
            context.stroke(cable, with: .color(ink), style: line)
        case .windmill:
            var sails = Path()
            for angle in stride(from: CGFloat.pi / 4, to: 2 * .pi, by: .pi / 2) {
                sails.move(to: CGPoint(x: 50, y: 42))
                sails.addLine(to: CGPoint(x: 50 + cos(angle) * 34, y: 42 + sin(angle) * 34))
            }
            context.stroke(sails, with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            context.stroke(sails, with: .color(.white), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        case .atomium:
            var tubes = Path()
            for (a, b) in [(0, 1), (0, 2), (1, 3), (2, 3), (3, 4), (3, 5), (4, 6), (5, 6), (0, 3), (3, 6)] {
                tubes.move(to: CGPoint(x: atomiumNodes[a].0, y: atomiumNodes[a].1))
                tubes.addLine(to: CGPoint(x: atomiumNodes[b].0, y: atomiumNodes[b].1))
            }
            context.stroke(tubes, with: .color(ink), style: StrokeStyle(lineWidth: 3))
            for (x, y) in atomiumNodes {
                context.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 5, width: 5, height: 5)), with: .color(.white.opacity(0.9)))
            }
        default:
            break
        }
    }
}

/// Map pin for a landmark during timeline playback.
final class LandmarkAnnotation: NSObject, MKAnnotation {
    let landmark: Landmark
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: landmark.coordinate.latitude, longitude: landmark.coordinate.longitude)
    }
    var title: String? { landmark.name }

    init(_ landmark: Landmark) {
        self.landmark = landmark
    }
}

final class LandmarkAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "LandmarkAnnotation"
    static let size = CGSize(width: 56, height: 56)
    private static var images: [Landmark.Style: UIImage] = [:]

    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(origin: .zero, size: Self.size)
        // The art's base, not its middle, sits on the coordinate.
        centerOffset = CGPoint(x: 0, y: -Self.size.height * 0.42)
        canShowCallout = true
        displayPriority = .required
        collisionMode = .none
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure() {
        guard let landmark = (annotation as? LandmarkAnnotation)?.landmark else { return }
        image = Self.image(for: landmark.style)
        accessibilityLabel = landmark.name
    }

    static func image(for style: Landmark.Style) -> UIImage? {
        if let cached = images[style] { return cached }
        let renderer = ImageRenderer(content: LandmarkArt(style: style).frame(width: size.width, height: size.height))
        renderer.scale = 3
        let image = renderer.uiImage
        images[style] = image
        return image
    }

    /// Cartoon pop-in when a landmark first appears.
    func popIn() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        transform = CGAffineTransform(scaleX: 0.05, y: 0.05).translatedBy(x: 0, y: 40)
        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
            self.transform = .identity
        }
    }
}

/// The moving tip of the journey line.
final class JourneyHeadAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(_ coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(80)), count: 4)) {
            ForEach(Landmark.Style.allCases, id: \.self) { style in
                LandmarkArt(style: style).frame(width: 80, height: 80)
            }
        }
    }
}
