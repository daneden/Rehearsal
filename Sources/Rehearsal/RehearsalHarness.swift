import SwiftUI
#if canImport(UIKit)
	import UIKit
#elseif canImport(AppKit)
	import AppKit
#endif

/// The interactive preview layout: the rehearsed view on top, a scrollable
/// control panel below, plus "Copy values as code" and "Reset" buttons.
///
/// ``Rehearse`` drives this view from its param declarations, but it can also
/// be wired up by hand with explicit `@State` and `ParameterControl`s.
public struct RehearsalHarness<Content: View>: View {
	private let title: String
	private let subjectName: String
	private let controls: [ParameterControl]
	private let reset: () -> Void
	private let content: Content

	@State private var justCopied = false

	public init(
		title: String,
		subjectName: String,
		controls: [ParameterControl],
		reset: @escaping () -> Void,
		@ViewBuilder content: () -> Content
	) {
		self.title = title
		self.subjectName = subjectName
		self.controls = controls
		self.reset = reset
		self.content = content()
	}

	public var body: some View {
		VStack(spacing: 0) {
			ZStack {
				content
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.padding()

			Divider()

			HStack {
				Text(title)
					.font(.headline)
				Spacer()
				Button {
					copyCode()
				} label: {
					Label(
						justCopied ? "Copied" : "Copy values as code",
						systemImage: justCopied ? "checkmark" : "doc.on.doc"
					)
				}
				Button("Reset", role: .destructive, action: reset)
			}
			.buttonStyle(.bordered)
			.controlSize(.small)
			.padding(.horizontal)
			.padding(.vertical, 10)

			Divider()

			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					ForEach(controls) { control in
						control.controlView
					}
				}
				.padding()
			}
			.frame(maxHeight: 320)
		}
	}

	/// The `Subject(param: value, ...)` snippet for the current values.
	public var codeString: String {
		rehearsalCallCode(subject: subjectName, controls: controls)
	}

	private func copyCode() {
		copyToPasteboard(codeString)
		justCopied = true
		Task {
			try? await Task.sleep(for: .seconds(1.5))
			justCopied = false
		}
	}
}

@MainActor
func copyToPasteboard(_ string: String) {
	#if canImport(UIKit)
		UIPasteboard.general.string = string
	#elseif canImport(AppKit)
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(string, forType: .string)
	#endif
}
