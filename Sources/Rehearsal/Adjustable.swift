import SwiftUI

/// The kind of control a adjustable type renders. Exposed so control selection
/// can be verified in tests without rendering views.
public enum ControlKind: String, Sendable, Equatable {
	/// A text field (`String`).
	case textField
	/// A toggle (`Bool`).
	case toggle
	/// A stepper, paired with a slider by default (`Int`).
	case stepper
	/// A slider (`Double`, or `Int` via `Parameters.slider`).
	case slider
	/// A color well (`Color`).
	case colorPicker
	/// A picker over a fixed set of values (enums and option lists).
	case picker
	/// A caller-supplied control view.
	case custom
}

/// A type that can be adjusted from the Rehearsal control panel.
///
/// Each conforming type knows how to render its own control row and how to
/// print its current value as a Swift source literal for "Copy values as code".
public protocol Adjustable {
	associatedtype ControlBody: View

	/// A complete control row (including its label) that edits `value`.
	@MainActor @ViewBuilder static func control(name: String, value: Binding<Self>) -> ControlBody

	/// The Swift source literal for the current value, e.g. `"Hello"`, `3`, `.compact`.
	var codeLiteral: String { get }

	static var controlKind: ControlKind { get }
}

/// A numeric ``Adjustable`` whose control can be constrained to a `range:`.
public protocol RangeAdjustable: Adjustable, Comparable {
	associatedtype RangedControlBody: View

	@MainActor @ViewBuilder static func control(name: String, value: Binding<Self>, range: ClosedRange<Self>) -> RangedControlBody

	/// The range used when a `Param` doesn't specify one.
	static var defaultRange: ClosedRange<Self> { get }
}

public extension RangeAdjustable {
	@MainActor static func control(name: String, value: Binding<Self>) -> RangedControlBody {
		control(name: name, value: value, range: defaultRange)
	}
}

// MARK: - String

extension String: Adjustable {
	public static func control(name: String, value: Binding<String>) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(name)
				.font(.caption)
				.foregroundStyle(.secondary)
			TextField(name, text: value)
				.textFieldStyle(.roundedBorder)
		}
	}

	public var codeLiteral: String {
		"\"\(swiftEscaped)\""
	}

	public static var controlKind: ControlKind {
		.textField
	}

	var swiftEscaped: String {
		var result = ""
		for scalar in unicodeScalars {
			switch scalar {
			case "\\": result += "\\\\"
			case "\"": result += "\\\""
			case "\n": result += "\\n"
			case "\t": result += "\\t"
			case "\r": result += "\\r"
			case "\0": result += "\\0"
			default: result.unicodeScalars.append(scalar)
			}
		}
		return result
	}
}

// MARK: - Bool

extension Bool: Adjustable {
	public static func control(name: String, value: Binding<Bool>) -> some View {
		Toggle(name, isOn: value)
	}

	public var codeLiteral: String {
		self ? "true" : "false"
	}

	public static var controlKind: ControlKind {
		.toggle
	}
}

// MARK: - Int

extension Int: RangeAdjustable {
	public static var defaultRange: ClosedRange<Int> {
		0 ... 100
	}

	public static func control(name: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			IntStepperRow(name: name, value: value, range: range)
			IntSliderBar(value: value, range: range)
		}
	}

	public var codeLiteral: String {
		String(self)
	}

	public static var controlKind: ControlKind {
		.stepper
	}
}

// MARK: - Double

extension Double: RangeAdjustable {
	public static var defaultRange: ClosedRange<Double> {
		0 ... 1
	}

	public static func control(name: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Text(name)
				Spacer()
				Text(value.wrappedValue, format: .number.precision(.fractionLength(0 ... 2)))
					.monospacedDigit()
					.foregroundStyle(.secondary)
			}
			Slider(value: value, in: range)
		}
	}

	/// Double's description is the shortest round-trip representation, so it is
	/// always a valid Swift literal ("0.3", "3.0").
	public var codeLiteral: String {
		"\(self)"
	}

	public static var controlKind: ControlKind {
		.slider
	}
}

// MARK: - Color

extension Color: Adjustable {
	public static func control(name: String, value: Binding<Color>) -> some View {
		ColorPicker(name, selection: value)
	}

	public var codeLiteral: String {
		let resolved = resolve(in: EnvironmentValues())
		let components = [resolved.red, resolved.green, resolved.blue, resolved.opacity]
			.map { Self.componentLiteral($0) }
		return "Color(red: \(components[0]), green: \(components[1]), blue: \(components[2]), opacity: \(components[3]))"
	}

	public static var controlKind: ControlKind {
		.colorPicker
	}

	private static func componentLiteral(_ value: Float) -> String {
		var text = String(format: "%.3f", Double(value))
		while text.hasSuffix("0") {
			text.removeLast()
		}
		if text.hasSuffix(".") { text.removeLast() }
		return text
	}
}

// MARK: - CaseIterable enums

/// Ready-made implementation for `CaseIterable` enums: declaring
/// `extension MyEnum: Adjustable {}` yields a picker over all cases.
///
/// Enums used with ``Rehearse`` don't need this conformance — `ParameterControl`
/// has a fallback initializer for any `CaseIterable & Hashable` type — but the
/// conformance lets an enum participate in hand-written harnesses like any
/// other `Adjustable`.
public extension Adjustable where Self: CaseIterable & Hashable, AllCases: RandomAccessCollection {
	@MainActor static func control(name: String, value: Binding<Self>) -> some View {
		OptionPicker(name: name, value: value, options: Array(allCases))
	}

	var codeLiteral: String {
		"." + String(describing: self)
	}

	static var controlKind: ControlKind {
		.picker
	}
}

/// Picker over a fixed list of values: segmented when there are few options,
/// a menu otherwise. Backs both `CaseIterable` enums (over `allCases`) and
/// explicit `param.picker(_:options:default:)` lists.
struct OptionPicker<Value: Hashable>: View {
	let name: String
	let value: Binding<Value>
	let options: [Value]

	var body: some View {
		if options.count <= 3 {
			VStack(alignment: .leading, spacing: 4) {
				Text(name)
					.font(.caption)
					.foregroundStyle(.secondary)
				corePicker
					.pickerStyle(.segmented)
					.labelsHidden()
			}
		} else {
			corePicker
				.pickerStyle(.menu)
		}
	}

	private var corePicker: some View {
		Picker(name, selection: value) {
			ForEach(options, id: \.self) { candidate in
				Text(String(describing: candidate)).tag(candidate)
			}
		}
	}
}
