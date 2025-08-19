import SwiftUI

// MARK: - Design System
struct FDPDesignSystem {
    // MARK: - Gradients
    static let primaryGradient = LinearGradient(
        colors: [
            Color(hex: "0F172A"),  // Deep navy
            Color(hex: "1E293B"),  // Slate 800
            Color(hex: "334155"),  // Slate 700
            Color(hex: "475569")   // Slate 600
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let secondaryGradient = LinearGradient(
        colors: [
            Color(hex: "F8FAFC"),  // Slate 50
            Color(hex: "F1F5F9"),  // Slate 100
            Color(hex: "E2E8F0")   // Slate 200
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let accentGradient = LinearGradient(
        colors: [
            Color(hex: "0EA5E9"),  // Sky 500
            Color(hex: "0284C7"),  // Sky 600
            Color(hex: "0369A1")   // Sky 700
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let successGradient = LinearGradient(
        colors: [
            Color(hex: "10B981"),  // Emerald 500
            Color(hex: "059669"),  // Emerald 600
            Color(hex: "047857")   // Emerald 700
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let warningGradient = LinearGradient(
        colors: [
            Color(hex: "F59E0B"),  // Amber 500
            Color(hex: "D97706"),  // Amber 600
            Color(hex: "B45309")   // Amber 700
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let dangerGradient = LinearGradient(
        colors: [
            Color(hex: "EF4444"),  // Red 500
            Color(hex: "DC2626"),  // Red 600
            Color(hex: "B91C1C")   // Red 700
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let cardGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.95),
            Color.white.opacity(0.85)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let glassGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.25),
            Color.white.opacity(0.1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Colors
    static let primary = Color(hex: "0F172A")      // Deep navy
    static let secondary = Color(hex: "475569")    // Slate 600
    static let accent = Color(hex: "0EA5E9")       // Sky 500
    static let background = Color(hex: "F8FAFC")   // Slate 50
    static let surface = Color.white
    static let textPrimary = Color(hex: "0F172A")  // Slate 900
    static let textSecondary = Color(hex: "475569") // Slate 600
    static let border = Color(hex: "E2E8F0")       // Slate 200
    static let success = Color(hex: "10B981")      // Emerald 500
    static let warning = Color(hex: "F59E0B")      // Amber 500
    static let danger = Color(hex: "EF4444")       // Red 500
    
    // MARK: - Shadows
    static let shadowSmall = Shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    static let shadowMedium = Shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    static let shadowLarge = Shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
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
            .background(FDPDesignSystem.cardGradient)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
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
            .background(FDPDesignSystem.glassGradient)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: FDPDesignSystem.shadowLarge.color,
                radius: FDPDesignSystem.shadowLarge.radius,
                x: FDPDesignSystem.shadowLarge.x,
                y: FDPDesignSystem.shadowLarge.y
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                FDPDesignSystem.accentGradient
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: FDPDesignSystem.shadowSmall.color,
                radius: FDPDesignSystem.shadowSmall.radius,
                x: FDPDesignSystem.shadowSmall.x,
                y: FDPDesignSystem.shadowSmall.y
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundColor(FDPDesignSystem.accent)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                FDPDesignSystem.cardGradient
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [FDPDesignSystem.accent.opacity(0.4), FDPDesignSystem.accent.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .cornerRadius(14)
            .shadow(
                color: FDPDesignSystem.shadowSmall.color,
                radius: FDPDesignSystem.shadowSmall.radius,
                x: FDPDesignSystem.shadowSmall.x,
                y: FDPDesignSystem.shadowSmall.y
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: color.opacity(0.3),
                radius: 4,
                x: 0,
                y: 2
            )
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
