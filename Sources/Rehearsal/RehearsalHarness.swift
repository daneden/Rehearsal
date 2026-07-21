import SwiftUI
#if canImport(UIKit)
	import UIKit
#elseif canImport(AppKit)
	import AppKit
#endif

/// The interactive preview layout: the rehearsed view fills the preview, and
/// the control panel floats alongside it — a resizable sheet on iOS and
/// visionOS (the preview stays visible and interactive behind it), a floating
/// overlay on macOS. Both minimize to a button in the bottom-trailing corner.
public struct RehearsalHarness<Content: View>: View {
	private let title: String
	private let subjectName: String
	private let controls: [ParameterControl]
	private let reset: () -> Void
	private let content: Content

	@State private var justCopied = false
	@State private var isExpanded = true

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
		ZStack(alignment: .bottomTrailing) {
			ZStack {
				content
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.padding()
			#if os(macOS)
				// Keep the rehearsed view visible beside the overlay panel.
				.padding(.trailing, isExpanded ? 376 : 0)
			#endif

			#if os(macOS)
				if isExpanded {
					overlayPanel
						.transition(.scale(scale: 0.1, anchor: .bottomTrailing).combined(with: .opacity))
				} else {
					expandButton
				}
			#else
				if !isExpanded {
					expandButton
				}
			#endif
		}
		#if !os(macOS)
		.sheet(isPresented: $isExpanded) {
			sheetPanel
		}
		#endif
	}

	/// The `Subject(param: value, ...)` snippet for the current values.
	public var codeString: String {
		rehearsalCallCode(subject: subjectName, controls: controls)
	}

	// MARK: - Panel pieces

	private var header: some View {
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
			Button {
				withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
					isExpanded = false
				}
			} label: {
				Image(systemName: "arrow.down.right.and.arrow.up.left")
			}
			.accessibilityLabel("Minimize controls")
		}
		.buttonStyle(.bordered)
		.controlSize(.small)
		.padding(.horizontal)
		.padding(.vertical, 10)
	}

	private var controlRows: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				ForEach(controls) { control in
					control.controlView
				}
			}
			.padding()
		}
	}

	/// The bottom-trailing floating button the panel minimizes to.
	private var expandButton: some View {
		Button {
			withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
				isExpanded = true
			}
		} label: {
			Image(systemName: "slider.horizontal.3")
				.font(.title3)
				.padding(14)
				.background(.regularMaterial, in: Circle())
				.overlay(Circle().strokeBorder(.quaternary))
				.shadow(color: .black.opacity(0.15), radius: 12, y: 4)
		}
		.buttonStyle(.plain)
		.padding()
		.accessibilityLabel("Show controls")
	}

	#if os(macOS)
		private var overlayPanel: some View {
			VStack(spacing: 0) {
				header
				Divider()
				controlRows
			}
			.frame(width: 360)
			.frame(maxHeight: 440)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
			.overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
			.shadow(color: .black.opacity(0.2), radius: 24, y: 8)
			.padding()
		}
	#else
		private var sheetPanel: some View {
			VStack(spacing: 0) {
				header
					.padding(.top, 6)
				Divider()
				controlRows
			}
			.presentationDetents([.height(360), .large])
			.presentationDragIndicator(.visible)
			.modifier(BackgroundInteractionModifier())
		}
	#endif

	private func copyCode() {
		copyToPasteboard(codeString)
		justCopied = true
		Task {
			try? await Task.sleep(for: .seconds(1.5))
			justCopied = false
		}
	}
}

#if !os(macOS)
	/// Keeps the preview behind the sheet interactive at the compact detent.
	/// Gated because the modifier requires iOS 16.4 while the package floor
	/// is 16.0; below 16.4 the sheet still works, without background interaction.
	private struct BackgroundInteractionModifier: ViewModifier {
		func body(content: Content) -> some View {
			if #available(iOS 16.4, macCatalyst 16.4, visionOS 1.0, *) {
				content.presentationBackgroundInteraction(.enabled(upThrough: .height(360)))
			} else {
				content
			}
		}
	}
#endif

@MainActor
func copyToPasteboard(_ string: String) {
	#if canImport(UIKit)
		UIPasteboard.general.string = string
	#elseif canImport(AppKit)
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(string, forType: .string)
	#endif
}
