import Rehearsal
import SwiftUI

enum CardStyle: CaseIterable, Hashable {
	case compact
	case regular
	case expanded
}

/// Deliberately not CaseIterable — the preview offers it via
/// `param.picker(_:options:default:)` instead.
enum Badge: Hashable {
	case hidden
	case new
	case sale
}

/// A demo view exercising every parameter type Rehearsal supports:
/// String, Int, Double, Bool, Color, and enums.
struct MyCard: View {
	var title: String
	var count: Int
	var progress: Double
	var isOn: Bool
	var tint: Color
	var style: CardStyle
	var badge: Badge

	var body: some View {
		VStack(alignment: .leading, spacing: style == .compact ? 6 : 12) {
			HStack {
				Text(title)
					.font(style == .expanded ? .largeTitle : .headline)
				if badge != .hidden {
					Text(badge == .new ? "NEW" : "SALE")
						.font(.caption2.bold())
						.padding(.horizontal, 6)
						.padding(.vertical, 2)
						.background(Capsule().fill(tint.opacity(0.25)))
				}
				Spacer()
				if isOn {
					Image(systemName: "star.fill")
						.foregroundStyle(tint)
				}
			}
			if style != .compact {
				ProgressView(value: progress)
					.tint(tint)
			}
			HStack(spacing: 5) {
				ForEach(0 ..< count, id: \.self) { _ in
					Circle()
						.fill(tint)
						.frame(width: 8, height: 8)
				}
			}
		}
		.padding()
		.background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.12)))
		.frame(maxWidth: 320)
	}
}

#Preview("My Card") {
	Rehearse(MyCard.self) { param in
		MyCard(
			title: param("title", default: "Hello"),
			count: param("count", range: 0 ... 10, default: 3),
			progress: param("progress", range: 0 ... 1, default: 0.4),
			isOn: param("isOn", default: true),
			tint: param("tint", default: .blue),
			style: param("style", default: .compact),
			badge: param.picker("badge", options: [.hidden, .new, .sale], default: .new)
		)
	}
}
