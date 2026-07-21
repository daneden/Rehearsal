import SwiftUI
#if canImport(UIKit)
	import UIKit
#elseif canImport(AppKit)
	import AppKit
#endif

/// The macOS split orientation used by ``RehearsalHarness``.
public enum RehearsalSplitOrientation: String, CaseIterable, Hashable, Sendable {
	/// Shows the rehearsed view and controls side by side, separated by a vertical divider.
	case vertical

	/// Shows the rehearsed view above the controls, separated by a horizontal divider.
	case horizontal
}

/// The interactive preview layout: the rehearsed view fills the preview, and
/// the control panel appears in a resizable split pane on macOS, or as a
/// resizable sheet on iOS and visionOS (the preview stays visible and
/// interactive behind it). Both minimize to a button in the bottom-trailing
/// corner.
public struct RehearsalHarness<Content: View>: View {
	private let title: String
	private let subjectName: String
	private let controls: [ParameterControl]
	private let reset: () -> Void
	private let content: Content
	private let initialSplitOrientation: RehearsalSplitOrientation

	@State private var justCopied = false
	@State private var isExpanded = true
	@State private var selectedSplitOrientation: RehearsalSplitOrientation?

	public init(
		title: String,
		subjectName: String,
		controls: [ParameterControl],
		reset: @escaping () -> Void,
		splitOrientation: RehearsalSplitOrientation = .vertical,
		@ViewBuilder content: () -> Content
	) {
		self.title = title
		self.subjectName = subjectName
		self.controls = controls
		self.reset = reset
		initialSplitOrientation = splitOrientation
		self.content = content()
	}

	public var body: some View {
		#if os(macOS)
			VStack(spacing: 0) {
				HStack {
					Spacer()

					Picker("Split orientation", selection: splitOrientation) {
						Label("Vertical", systemImage: "rectangle.split.2x1")
							.tag(RehearsalSplitOrientation.vertical)
							.labelStyle(.iconOnly)
						Label("Horizontal", systemImage: "rectangle.split.1x2")
							.tag(RehearsalSplitOrientation.horizontal)
							.labelStyle(.iconOnly)
					}
					.pickerStyle(.segmented)
					.labelsHidden()

					expandButton
				}
				.controlSize(.mini)
				.padding(8)
				.background(.regularMaterial)

				Divider()

				if isExpanded {
					macOSSplitLayout
				} else {
					previewPane
				}
			}
		#else
			VStack {
				previewPane
			}
			.padding(.bottom, isExpanded ? 360 : 0)
			.animation(.default, value: isExpanded)
			.toolbar {
				ToolbarItem(placement: .bottomBar) {
					expandButton
				}
			}
			.sheet(isPresented: $isExpanded) {
				sheetPanel
			}
		#endif
	}

	/// The `Subject(param: value, ...)` snippet for the current values.
	public var codeString: String {
		rehearsalCallCode(subject: subjectName, controls: controls)
	}

	private var currentSplitOrientation: RehearsalSplitOrientation {
		selectedSplitOrientation ?? initialSplitOrientation
	}

	private var splitOrientation: Binding<RehearsalSplitOrientation> {
		Binding(
			get: { currentSplitOrientation },
			set: { selectedSplitOrientation = $0 }
		)
	}

	// MARK: - Panel pieces

	private var previewPane: some View {
		ZStack {
			content
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding()
	}

	private var resetButton: some View {
		Button("Reset", systemImage: "arrow.counterclockwise", action: reset)
			.labelStyle(.iconOnly)
	}

	private var copyCodeButton: some View {
		Button {
			copyCode()
		} label: {
			Label(
				justCopied ? "Copied" : "Copy code",
				systemImage: justCopied ? "checkmark" : "doc.on.doc"
			)
		}
	}

	private var header: some View {
		HStack {
			Text(title)
				.font(.headline)
			Spacer()

			copyCodeButton

			resetButton
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
		Toggle(isOn: $isExpanded) {
			Label("Toggle controls", systemImage: "slider.horizontal.3")
				.labelStyle(.iconOnly)
		}
		.toggleStyle(.button)
	}

	#if os(macOS)
		@ViewBuilder
		private var macOSSplitLayout: some View {
			switch currentSplitOrientation {
			case .vertical:
				HSplitView {
					previewPane
						.frame(minWidth: 240)
					macOSControlsPane
						.frame(minWidth: 280, idealWidth: 360)
				}
			case .horizontal:
				VSplitView {
					previewPane
						.frame(minHeight: 180)
					macOSControlsPane
						.frame(minHeight: 220, idealHeight: 320)
				}
			}
		}

		private var macOSControlsPane: some View {
			VStack(spacing: 0) {
				header
				Divider()
				controlRows
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(.regularMaterial)
		}
	#else
		private var sheetPanel: some View {
			NavigationStack {
				controlRows
					.navigationTitle(Text(title))
					.navigationBarTitleDisplayMode(.inline)
					.toolbar {
						copyCodeButton
						resetButton
					}
			}
			.presentationDetents([.height(360)])
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
