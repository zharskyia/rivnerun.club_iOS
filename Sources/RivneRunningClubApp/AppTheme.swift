import SwiftUI

enum AppTheme {
    static let black = Color(red: 35 / 255, green: 31 / 255, blue: 32 / 255)
    static let yellow = Color(red: 255 / 255, green: 223 / 255, blue: 18 / 255)
    static let green = Color(red: 0 / 255, green: 196 / 255, blue: 0 / 255)
    static let white = Color.white
    static let muted = Color(red: 104 / 255, green: 104 / 255, blue: 104 / 255)
    static let background = Color(red: 245 / 255, green: 245 / 255, blue: 242 / 255)
    static let card = Color(red: 251 / 255, green: 251 / 255, blue: 248 / 255)
    static let shadow = Color.black.opacity(0.12)
    static let softGreen = Color(red: 226 / 255, green: 247 / 255, blue: 232 / 255)
}

struct RotatedCornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset: CGFloat = 10
        let right = rect.maxX
        let bottom = rect.maxY

        path.move(to: CGPoint(x: inset, y: 0))
        path.addLine(to: CGPoint(x: right, y: 0))
        path.addLine(to: CGPoint(x: right - inset, y: bottom))
        path.addLine(to: CGPoint(x: 0, y: bottom))
        path.closeSubpath()
        return path
    }
}

struct RotatedButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .clipShape(RotatedCornerShape())
            .shadow(color: AppTheme.shadow, radius: 4, x: 0, y: 4)
    }
}

extension View {
    func rotatedButtonStyle() -> some View {
        modifier(RotatedButtonModifier())
    }
}

extension Color {
    init?(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hexSanitized)
        if hexSanitized.hasPrefix("#") {
            scanner.currentIndex = scanner.string.index(after: scanner.currentIndex)
        }
        var value: UInt64 = 0
        guard scanner.scanHexInt64(&value) else { return nil }

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
