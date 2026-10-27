import AppKit
import SwiftUI

/// revel8 logo artwork (from revel8-white-logo.svg / revel8-eight.svg), drawn as vector shapes.
enum Brand {
    // The "8": a gradient-filled stroke behind a solid white stroke. viewBox 0 0 51 74.
    static let eightViewBox = CGRect(x: 0, y: 0, width: 50.5502, height: 73.6588)
    static let eightBack = "M17.7441 26.3067L39.8212 38.6864C48.6932 43.8445 50.5502 50.6533 50.5502 56.3273C50.5502 66.7469 42.2971 73.6588 30.9491 73.6588H24.8624V62.7235H31.2586C36.4168 62.7235 38.9959 59.6286 38.9959 56.0178C38.9959 53.3356 37.9642 50.3438 32.806 47.3521L10.729 34.9725C1.54745 29.608 0 23.0055 0 17.3315C0 6.91196 8.25309 0 19.6011 0H25.2751V10.9353H19.2916C14.1334 10.9353 11.5543 14.0303 11.5543 17.641C11.5543 20.3232 12.7923 23.4181 17.7441 26.3067Z"
    static let eightFront = "M32.806 26.3067L10.729 38.6864C1.85695 43.8445 0 50.6533 0 56.3273C0 66.7469 8.25309 73.6588 19.6011 73.6588H25.4814V62.7235H19.2916C14.1334 62.7235 11.5543 59.6286 11.5543 56.0178C11.5543 53.3356 12.586 50.3438 17.7441 47.3521L39.8212 34.9725C49.0027 29.608 50.5502 23.0055 50.5502 17.3315C50.5502 6.91196 42.2971 0 30.9491 0H24.6561V10.9353H31.2586C36.4168 10.9353 38.9959 14.0303 38.9959 17.641C38.9959 20.3232 37.7579 23.4181 32.806 26.3067Z"

    // Wordmark "revel8". viewBox 0 0 254 76.
    static let wordmarkViewBox = CGRect(x: 0, y: 0, width: 253.968, height: 75.3787)
    static let wordmarkEightBack = "M220.254 26.6353L242.331 39.015C251.203 44.1732 253.06 50.982 253.06 56.656C253.06 67.0755 244.807 73.9874 233.459 73.9874H227.373V63.0521H233.769C238.927 63.0521 241.506 59.9572 241.506 56.3465C241.506 53.6642 240.474 50.6725 235.316 47.6807L213.239 35.3011C204.058 29.9366 202.51 23.3341 202.51 17.6601C202.51 7.24058 210.763 0.328613 222.111 0.328613H227.785V11.264H221.802C216.644 11.264 214.065 14.3589 214.065 17.9696C214.065 20.6518 215.303 23.7468 220.254 26.6353Z"
    static let wordmarkSolid = [
        "M235.316 26.6353L213.239 39.015C204.367 44.1732 202.51 50.982 202.51 56.656C202.51 67.0755 210.763 73.9874 222.111 73.9874H227.992V63.0521H221.802C216.644 63.0521 214.065 59.9572 214.065 56.3465C214.065 53.6642 215.096 50.6725 220.254 47.6807L242.331 35.3011C251.513 29.9366 253.06 23.3341 253.06 17.6601C253.06 7.24058 244.807 0.328613 233.459 0.328613H227.166V11.264H233.769C238.927 11.264 241.506 14.3589 241.506 17.9696C241.506 20.6518 240.268 23.7468 235.316 26.6353Z",
        "M165.474 56.9653C163.824 62.8456 158.459 64.2899 153.611 64.2899C146.699 64.2899 141.334 59.0286 140.715 51.1882H177.854V47.4743C177.854 31.4839 168.879 20.7549 153.507 20.7549C139.374 20.7549 128.335 30.9681 128.335 47.8869C128.335 63.3615 138.652 74.8126 153.611 74.8126C165.474 74.8126 175.688 68.5196 178.06 56.9653H165.474ZM153.507 31.2776C160.419 31.2776 164.752 34.8883 165.474 41.9034H140.921C142.159 35.301 146.699 31.2776 153.507 31.2776Z",
        "M66.6438 56.9653C64.9932 62.8456 59.6287 64.2899 54.78 64.2899C47.868 64.2899 42.5035 59.0286 41.8845 51.1882H79.0234V47.4743C79.0234 31.4839 70.0482 20.7549 54.6768 20.7549C40.5434 20.7549 29.5049 30.9681 29.5049 47.8869C29.5049 63.3615 39.8212 74.8126 54.78 74.8126C66.6438 74.8126 76.857 68.5196 79.2298 56.9653H66.6438ZM54.6768 31.2776C61.5888 31.2776 65.9216 34.8883 66.6438 41.9034H42.0908C43.3288 35.301 47.868 31.2776 54.6768 31.2776Z",
        "M111.314 73.5747H96.2517L78.3013 21.9929H91.0936L103.473 60.9888H104.092L116.472 21.9929H129.264L111.314 73.5747Z",
        "M195.908 0.741211H183.941V73.5747H195.908V0.741211Z",
        "M11.967 41.9035V73.5747H0V39.8402C0 27.6669 7.22145 21.9929 19.3948 21.9929H27.6479V33.1346H20.7359C14.9587 33.1346 11.967 35.0947 11.967 41.9035Z"
    ]

    /// The SVG's white → transparent → white fill on the back stroke of the 8.
    static func eightGradient(start: UnitPoint, end: UnitPoint) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .white, location: 0.05),
            .init(color: .white.opacity(0), location: 0.49),
            .init(color: .white, location: 0.94)
        ], startPoint: start, endPoint: end)
    }
}

// MARK: - Views

/// The revel8 "8" mark, white on transparent.
struct RevelEight: View {
    var body: some View {
        ZStack {
            SVGShape(Brand.eightBack, viewBox: Brand.eightViewBox)
                .fill(Brand.eightGradient(start: UnitPoint(x: 0.30, y: 0.19), end: UnitPoint(x: 0.70, y: 0.82)))
            SVGShape(Brand.eightFront, viewBox: Brand.eightViewBox)
                .fill(.white)
        }
        .aspectRatio(Brand.eightViewBox.width / Brand.eightViewBox.height, contentMode: .fit)
        .accessibilityLabel("revel8")
    }
}

/// The full "revel8" wordmark, white on transparent.
struct RevelWordmark: View {
    var body: some View {
        ZStack {
            SVGShape(Brand.wordmarkEightBack, viewBox: Brand.wordmarkViewBox)
                .fill(Brand.eightGradient(start: UnitPoint(x: 0.858, y: 0.19), end: UnitPoint(x: 0.937, y: 0.81)))
            ForEach(Brand.wordmarkSolid.indices, id: \.self) { i in
                SVGShape(Brand.wordmarkSolid[i], viewBox: Brand.wordmarkViewBox).fill(.white)
            }
        }
        .aspectRatio(Brand.wordmarkViewBox.width / Brand.wordmarkViewBox.height, contentMode: .fit)
        .accessibilityLabel("revel8")
    }
}

// MARK: - Minimal SVG path support (absolute M, L, H, V, C, Z — what the logo uses)

struct SVGShape: Shape {
    let path: Path
    let viewBox: CGRect

    init(_ d: String, viewBox: CGRect) {
        self.path = SVGPathParser.parse(d)
        self.viewBox = viewBox
    }

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let dx = rect.minX + (rect.width - viewBox.width * scale) / 2 - viewBox.minX * scale
        let dy = rect.minY + (rect.height - viewBox.height * scale) / 2 - viewBox.minY * scale
        return path.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: dx, ty: dy))
    }
}

enum SVGPathParser {
    static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var current = ""
        for ch in d {
            if ch.isLetter {
                if !current.isEmpty { tokens.append(current); current = "" }
                tokens.append(String(ch))
            } else if ch == " " || ch == "," {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else if ch == "-" && !current.isEmpty && !current.hasSuffix("e") {
                tokens.append(current); current = "-"
            } else if ch == "." && current.contains(".") {
                tokens.append(current); current = "."
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(current) }

        var path = Path()
        var i = 0
        var command: Character = "M"
        var point = CGPoint.zero
        func num() -> CGFloat {
            defer { i += 1 }
            return CGFloat(Double(tokens[i]) ?? 0)
        }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter {
                command = c
                i += 1
                if c == "Z" || c == "z" { path.closeSubpath(); continue }
            }
            switch command {
            case "M":
                point = CGPoint(x: num(), y: num()); path.move(to: point); command = "L"
            case "L":
                point = CGPoint(x: num(), y: num()); path.addLine(to: point)
            case "H":
                point = CGPoint(x: num(), y: point.y); path.addLine(to: point)
            case "V":
                point = CGPoint(x: point.x, y: num()); path.addLine(to: point)
            case "C":
                let c1 = CGPoint(x: num(), y: num())
                let c2 = CGPoint(x: num(), y: num())
                point = CGPoint(x: num(), y: num())
                path.addCurve(to: point, control1: c1, control2: c2)
            default:
                i += 1 // unsupported command: skip
            }
        }
        return path
    }
}
