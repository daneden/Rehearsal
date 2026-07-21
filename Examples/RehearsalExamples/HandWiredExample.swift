import Rehearsal
import SwiftUI

/// The same harness `Rehearse` builds, wired by hand — useful as a reference
/// for what `Rehearse` does, and usable directly when you need full control
/// over the state.
private struct HandWiredHost: View {
	@State private var title: String = "Hello"
	@State private var count: Int = 3
	@State private var progress: Double = 0.4
	@State private var isOn: Bool = true
	@State private var tint: Color = .blue
	@State private var style: CardStyle = .compact
	@State private var badge: Badge = .new

	/// The @State macro (SDK 27) suppresses synthesized initializers, so views
	/// with @State need an explicit one.
	init() {}

	var body: some View {
		RehearsalHarness(
			title: "My Card (hand-wired)",
			subjectName: "MyCard",
			controls: [
				ParameterControl("title", $title),
				ParameterControl("count", $count, range: 0 ... 10),
				ParameterControl("progress", $progress, range: 0 ... 1),
				ParameterControl("isOn", $isOn),
				ParameterControl("tint", $tint),
				ParameterControl("style", $style),
				// The custom-control escape hatch, hand-wired: any view
				// driven by a Binding, plus the code literal for copying.
				ParameterControl("badge", $badge, kind: .picker, code: { ".\($0)" }) { value in
					Picker("badge", selection: value) {
						Text("hidden").tag(Badge.hidden)
						Text("new").tag(Badge.new)
						Text("sale").tag(Badge.sale)
					}
					.pickerStyle(.menu)
				},
			],
			reset: {
				title = "Hello"
				count = 3
				progress = 0.4
				isOn = true
				tint = .blue
				style = .compact
				badge = .new
			}
		) {
			MyCard(title: title, count: count, progress: progress, isOn: isOn, tint: tint, style: style, badge: badge)
		}
	}
}

#Preview("My Card (hand-wired)") {
	HandWiredHost()
}
