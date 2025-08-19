import SwiftUI

// MARK: - Design System
struct FDPDesignSystem {
    // MARK: - Colors
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "1E3A8A"), Color(hex: "3B82F6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let secondaryGradient = LinearGradient(
        colors: [Color(hex: "F8FAFC"), Color(hex: "E2E8F0")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "10B981"), Color(hex: "059669")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let warningGradient = LinearGradient(
        colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let dangerGradient = LinearGradient(
        colors: [Color(hex: "EF4444"), Color(hex: "DC2626")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Colors
    static let primary = Color(hex: "1E3A8A")
    static let secondary = Color(hex: "64748B")
    static let accent = Color(hex: "10B981")
    static let background = Color(hex: "F8FAFC")
    static let surface = Color.white
    static let textPrimary = Color(hex: "1E293B")
    static let textSecondary = Color(hex: "64748B")
    static let border = Color(hex: "E2E8F0")
    static let success = Color(hex: "10B981")
    static let warning = Color(hex: "F59E0B")
    static let danger = Color(hex: "EF4444")
    
    // MARK: - Shadows
    static let shadowSmall = Shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    static let shadowMedium = Shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    static let shadowLarge = Shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(FDPDesignSystem.surface)
            .cornerRadius(16)
            .shadow(
                color: FDPDesignSystem.shadowMedium.color,
                radius: FDPDesignSystem.shadowMedium.radius,
                x: FDPDesignSystem.shadowMedium.x,
                y: FDPDesignSystem.shadowMedium.y
            )
    }
}

struct GlassmorphismStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                FDPDesignSystem.primaryGradient
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundColor(FDPDesignSystem.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                FDPDesignSystem.surface
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(FDPDesignSystem.primary.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Custom Components
struct FDPCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .modifier(CardStyle())
    }
}

struct FDPBadge: View {
    let text: String
    let color: Color
    
    init(_ text: String, color: Color = FDPDesignSystem.accent) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(8)
    }
}

struct FDPIcon: View {
    let systemName: String
    let color: Color
    let size: CGFloat
    
    init(_ systemName: String, color: Color = FDPDesignSystem.primary, size: CGFloat = 20) {
        self.systemName = systemName
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundColor(color)
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func glassmorphismStyle() -> some View {
        modifier(GlassmorphismStyle())
    }
    
    func primaryButtonStyle() -> some View {
        buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryButtonStyle() -> some View {
        buttonStyle(SecondaryButtonStyle())
    }
}
