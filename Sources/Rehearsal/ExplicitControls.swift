import SwiftUI

/// Explicit control choices: `param(...)` picks a control from the value's
/// type, and these methods override that choice for one parameter — or supply
/// a control Rehearsal doesn't know how to build.
public extension Parameters {
	/// Renders an `Int` parameter as a plain slider (no stepper).
	func slider(_ name: String, range: ClosedRange<Int>, default defaultValue: Int, animation: Animation? = nil) -> Int {
		let control = ParameterControl(name, binding(name, default: defaultValue, animation: animation), kind: .slider, code: \.codeLiteral) {
			IntSliderRow(name: name, value: $0, range: range)
		}
		return declare(control, name, default: defaultValue)
	}

	/// Renders a `Double` parameter as a slider with an explicit range —
	/// the default control, exposed for symmetry with the `Int` override.
	func slider(_ name: String, range: ClosedRange<Double>, default defaultValue: Double, animation: Animation? = nil) -> Double {
		let control = ParameterControl(name, binding(name, default: defaultValue, animation: animation), kind: .slider, code: \.codeLiteral) {
			Double.control(name: name, value: $0, range: range)
		}
		return declare(control, name, default: defaultValue)
	}

	/// Renders an `Int` parameter as a stepper only (no slider).
	func stepper(_ name: String, range: ClosedRange<Int> = 0 ... 100, default defaultValue: Int, animation: Animation? = nil) -> Int {
		let control = ParameterControl(name, binding(name, default: defaultValue, animation: animation), kind: .stepper, code: \.codeLiteral) {
			IntStepperRow(name: name, value: $0, range: range)
		}
		return declare(control, name, default: defaultValue)
	}

	/// A picker over an explicit list of values — for enums that aren't
	/// `CaseIterable`, or any `Hashable` type with a meaningful option set.
	///
	/// `options` must be distinct and contain `default`; both are asserted in
	/// debug builds, since a selection outside the tagged options renders as
	/// no selection at all.
	func picker<Value: Hashable>(_ name: String, options: [Value], default defaultValue: Value, animation: Animation? = nil) -> Value {
		assert(options.contains(defaultValue),
		       "Rehearse: the default for \"\(name)\" is not in its options")
		assert(Set(options).count == options.count,
		       "Rehearse: the options for \"\(name)\" contain duplicates")
		let control = ParameterControl(name, binding(name, default: defaultValue, animation: animation), kind: .picker, code: optionCodeLiteral) {
			OptionPicker(name: name, value: $0, options: options)
		}
		return declare(control, name, default: defaultValue)
	}

	/// A fully custom control for one parameter — the escape hatch for types
	/// Rehearsal doesn't know, like a custom struct. (To reuse a control for
	/// every parameter of a type, conform the type to ``Adjustable`` instead.)
	///
	/// `code` supplies the value's Swift literal for "Copy values as code";
	/// the default `String(describing:)` is readable but not guaranteed to be
	/// compilable source.
	///
	/// ```swift
	/// let insets = param.custom("insets", default: EdgeInsets()) { value in
	///     InsetsEditor(insets: value)
	/// }
	/// ```
	func custom<Value, ControlBody: View>(
		_ name: String,
		default defaultValue: Value,
		animation: Animation? = nil,
		code: @escaping (Value) -> String = { String(describing: $0) },
		@ViewBuilder control: (Binding<Value>) -> ControlBody
	) -> Value {
		let row = ParameterControl(name, binding(name, default: defaultValue, animation: animation), code: code, control: control)
		return declare(row, name, default: defaultValue)
	}
}

/// The Swift literal for a picker option: `Adjustable` values know their own
/// literal, enum cases get the leading-dot form, everything else falls back
/// to `String(describing:)`.
func optionCodeLiteral<Value>(_ value: Value) -> String {
	if let adjustable = value as? any Adjustable {
		return adjustable.codeLiteral
	}
	if Mirror(reflecting: value).displayStyle == .enum {
		return "." + String(describing: value)
	}
	return String(describing: value)
}

/// Slider-only row for `Int` (the forced `.slider` control).
struct IntSliderRow: View {
	let name: String
	let value: Binding<Int>
	let range: ClosedRange<Int>

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Text(name)
				Spacer()
				Text("\(value.wrappedValue)")
					.monospacedDigit()
					.foregroundStyle(.secondary)
			}
			IntSliderBar(value: value, range: range)
		}
	}
}

/// Stepper-only row for `Int` (the forced `.stepper` control).
struct IntStepperRow: View {
	let name: String
	let value: Binding<Int>
	let range: ClosedRange<Int>

	var body: some View {
		Stepper(value: value, in: range) {
			HStack {
				Text(name)
				Spacer()
				Text("\(value.wrappedValue)")
					.monospacedDigit()
					.foregroundStyle(.secondary)
			}
		}
	}
}

/// The `Int`-backed slider shared by `Int`'s default control and the forced
/// `.slider` override.
struct IntSliderBar: View {
	let value: Binding<Int>
	let range: ClosedRange<Int>

	var body: some View {
		Slider(
			value: Binding(
				get: { Double(value.wrappedValue) },
				set: { value.wrappedValue = Int($0.rounded()) }
			),
			in: Double(range.lowerBound) ... Double(range.upperBound),
			step: 1
		)
	}
}
