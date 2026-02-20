import SwiftUI

enum AppPalette {
    static let bgStart = Color(hex: 0x07131C)
    static let bgEnd = Color(hex: 0x02070B)
    static let panel = Color(hex: 0x0E1E29)
    static let panelSoft = Color(hex: 0x132734)

    static let neonCyan = Color(hex: 0x00E5FF)
    static let neonMint = Color(hex: 0x3CF2BC)
    static let neonAmber = Color(hex: 0xFFB34D)
    static let neonRed = Color(hex: 0xFF6B6B)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
}

enum AppTypography {
    static func title(_ size: CGFloat = 34) -> Font {
        .custom("AvenirNextCondensed-Bold", size: size)
    }

    static func heading(_ size: CGFloat = 22) -> Font {
        .custom("AvenirNext-DemiBold", size: size)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .custom("AvenirNext-Regular", size: size)
    }

    static func mono(_ size: CGFloat = 14) -> Font {
        .custom("Menlo-Regular", size: size)
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [AppPalette.bgStart, AppPalette.bgEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Circle()
                .fill(AppPalette.neonCyan.opacity(0.12))
                .frame(width: 280, height: 280)
                .offset(x: 140, y: -240)
        )
        .overlay(
            Circle()
                .fill(AppPalette.neonMint.opacity(0.1))
                .frame(width: 220, height: 220)
                .offset(x: -120, y: 320)
        )
        .ignoresSafeArea()
    }
}

struct NeonCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppPalette.panel.opacity(0.86))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.neonCyan.opacity(0.18), lineWidth: 1)
            )
    }
}

extension View {
    func neonCard() -> some View {
        modifier(NeonCardModifier())
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
