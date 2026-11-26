import SwiftUI

/// Design tokens and shared components: light surfaces, one blue accent,
/// white cards with hairline borders, pill buttons.
enum Theme {
    static let accent = Color(red: 0.16, green: 0.49, blue: 0.96)
    static let accentSoft = Color(red: 0.16, green: 0.49, blue: 0.96).opacity(0.10)
    static let ink = Color(red: 0.07, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.45, green: 0.49, blue: 0.56)
    static let bg = Color(red: 0.965, green: 0.969, blue: 0.976)
    static let card = Color.white
    static let line = Color(red: 0.92, green: 0.93, blue: 0.95)
    static let cardRadius: CGFloat = 22

    static func color(for kind: SessionKind) -> Color {
        switch kind {
        case .easyRun, .longRun, .recovery: return Color(red: 0.13, green: 0.70, blue: 0.47)
        case .intervals, .tempo: return accent
        case .strength: return Color(red: 0.49, green: 0.36, blue: 0.93)
        case .stations: return Color(red: 0.96, green: 0.55, blue: 0.13)
        case .compromised: return Color(red: 0.93, green: 0.29, blue: 0.33)
        case .simulation, .race: return Color(red: 0.05, green: 0.25, blue: 0.62)
        case .rest: return muted
        }
    }
}

struct Card<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}

/// Full-width blue capsule, the app's primary action.
struct PillButtonStyle: ButtonStyle {
    var fill: Color = Theme.accent
    var text: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(fill.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

/// White circle icon button, as used in the header.
struct CircleIcon: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: 44, height: 44)
            .background(Theme.card, in: Circle())
            .overlay(Circle().stroke(Theme.line, lineWidth: 1))
    }
}

/// Rounded tinted square holding a symbol.
struct IconTile: View {
    let symbol: String
    var color: Color = Theme.accent
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

struct KindBadge: View {
    let kind: SessionKind
    var size: CGFloat = 42
    var body: some View { IconTile(symbol: kind.symbol, color: Theme.color(for: kind), size: size) }
}

struct Pill: View {
    let text: String
    var icon: String? = nil
    var color: Color = Theme.muted

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.10), in: Capsule())
    }
}

/// Capsule segmented control: white track, blue selection.
struct SegmentedPills<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(on ? Color.white : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(on ? Theme.accent : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }
}

/// Small grey label over a value, with a leading icon tile.
struct FieldRow: View {
    let symbol: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(Theme.muted)
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
        }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.title3.weight(.bold)).foregroundStyle(Theme.ink).padding(.top, 6)
    }
}

/// Poster-style line: a big blue quantity followed by the movement.
struct QuantityText: View {
    let item: String
    var dimmed = false

    var body: some View {
        let parts = Fmt.quantity(item)
        Group {
            if let qty = parts.qty {
                BigAmount(amount: qty, label: parts.rest, amountColor: dimmed ? Theme.muted : Theme.accent, labelColor: dimmed ? Theme.muted : Theme.ink)
            } else {
                Text(parts.rest).font(.subheadline.weight(.medium)).foregroundColor(dimmed ? Theme.muted : Theme.ink)
            }
        }
        .multilineTextAlignment(.leading)
    }
}

/// A heavy rounded amount followed by its label, as one wrapping line of text.
struct BigAmount: View {
    let amount: String
    let label: String
    var amountColor: Color = Theme.accent
    var labelColor: Color = Theme.ink
    var labelWeight: Font.Weight = .semibold

    var body: some View {
        let big: Text = Text(amount).font(.system(.title3, design: .rounded).weight(.heavy)).foregroundColor(amountColor)
        let small: Text = Text("  " + label).font(.subheadline.weight(labelWeight)).foregroundColor(labelColor)
        return big + small
    }
}

/// Solid strip behind the status bar for screens that hide the navigation bar.
struct StatusBarStrip: View {
    var body: some View {
        Theme.bg.frame(height: 0).ignoresSafeArea(edges: .top)
    }
}
