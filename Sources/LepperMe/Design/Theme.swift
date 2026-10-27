import AppKit
import CoreText
import SwiftUI

/// revel8 design tokens (Figma "revel8 - master file"). Use these instead of raw colors.
enum Theme {
    // MARK: Palette (Global tokens)

    enum Grey {
        static let g1000 = Color(hex: 0x051520) // brand navy
        static let g950 = Color(hex: 0x11202B)
        static let g900 = Color(hex: 0x1E2C36)
        static let g800 = Color(hex: 0x37434C)
        static let g700 = Color(hex: 0x505B63)
        static let g500 = Color(hex: 0x828A8F)
        static let g300 = Color(hex: 0xB4B9BC)
        static let g100 = Color(hex: 0xE6E8E9)
        static let g0 = Color(hex: 0xFFFFFF)
    }

    enum Blue {
        static let b700 = Color(hex: 0x204763)
        static let b500 = Color(hex: 0x3D7A9A)
        static let b400 = Color(hex: 0x4B93B5)
        static let b300 = Color(hex: 0x6AABC3)
        static let b100 = Color(hex: 0xA7DCDF)
    }

    enum Green {
        static let g500 = Color(hex: 0x37A160)
        static let g400 = Color(hex: 0x4EC46E)
    }

    static let red600 = Color(hex: 0xB41F43)
    static let red500 = Color(hex: 0xD33F51)
    static let purple600 = Color(hex: 0x7A328F)

    // MARK: Alias tokens (dark surfaces)

    static let backgroundCanvas = Grey.g1000
    static let backgroundRaised = Grey.g950
    static let backgroundElevated = Grey.g900
    static let backgroundOverlay = Grey.g1000 // color/background/core/overlay is g1000 @ 70 %
    static let contentPrimary = Grey.g0
    static let contentSubdued = Grey.g300
    static let contentDisabled = Grey.g500
    static let borderPrimary = Grey.g800
    static let borderSubdued = Grey.g900
    static let accent = Blue.b400
    static let success = Green.g400
    static let buttonPrimary = Grey.g0
    static let buttonPrimaryContent = Grey.g1000
    static let buttonSecondary = Grey.g900

    /// revel8 "ai-gradient": blue → red → purple.
    static let brandGradientStops: [Color] = [Blue.b400, red600, purple600]

    static var brandGradient: LinearGradient {
        LinearGradient(colors: brandGradientStops, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var ringGradient: AngularGradient {
        AngularGradient(
            colors: [Blue.b300, Blue.b400, purple600, red500, Blue.b300],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    // MARK: Radius & spacing

    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 16
    }

    enum Space {
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s24: CGFloat = 24
        static let s32: CGFloat = 32
        static let s48: CGFloat = 48
    }

    // MARK: Typography (Geist 400 / 600, falls back to SF Pro if Geist isn't bundled)

    enum Weight { case regular, semibold }

    static func font(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        let name = weight == .regular ? "Geist-Regular" : "Geist-SemiBold"
        if FontLoader.hasGeist {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight == .regular ? .regular : .semibold)
    }

    /// heading/large: 24 / 600 / tracking -0.96
    static var headingLarge: Font { font(24, .semibold) }
    static var bodyLarge: Font { font(16) }
    static var bodyLargeStrong: Font { font(16, .semibold) }
    static var bodyMedium: Font { font(14) }
    static var bodyMediumStrong: Font { font(14, .semibold) }
    static var caption: Font { font(12) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Registers fonts shipped in the app bundle (Contents/Resources/Fonts) for this process.
enum FontLoader {
    private(set) static var hasGeist = false

    static func registerBundledFonts() {
        if let dir = Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
           let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for url in files where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        hasGeist = NSFont(name: "Geist-Regular", size: 12) != nil && NSFont(name: "Geist-SemiBold", size: 12) != nil
    }
}
