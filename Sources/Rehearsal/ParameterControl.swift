import SwiftUI

/// A type-erased, named control row: the view that edits one parameter plus
/// the pieces the harness needs for code generation.
public struct ParameterControl: Identifiable {
	public let name: String
	public let kind: ControlKind

	let controlView: AnyView
	let codeLiteral: () -> String

	public var id: String {
		name
	}

	/// A control row for an ``Adjustable`` value, using the type's default
	/// control.
	@MainActor
	public init<Value: Adjustable>(_ name: String, _ value: Binding<Value>) {
		self.name = name
		kind = Value.controlKind
		controlView = AnyView(Value.control(name: name, value: value))
		codeLiteral = { value.wrappedValue.codeLiteral }
	}

	/// A control row for a numeric value, constrained to `range`.
	@MainActor
	public init<Value: RangeAdjustable>(_ name: String, _ value: Binding<Value>, range: ClosedRange<Value>) {
		self.name = name
		kind = Value.controlKind
		controlView = AnyView(Value.control(name: name, value: value, range: range))
		codeLiteral = { value.wrappedValue.codeLiteral }
	}

	/// Fallback for `CaseIterable` enums that don't declare an `Adjustable`
	/// conformance. ``Parameters`` relies on this overload so plain enums
	/// work with ``Rehearse`` unmodified. Disfavored so that a type conforming to
	/// both `Adjustable` and `CaseIterable` resolves to its own conformance.
	@_disfavoredOverload
	@MainActor
	public init<Value: CaseIterable & Hashable>(
		_ name: String,
		_ value: Binding<Value>
	) where Value.AllCases: RandomAccessCollection {
		self.name = name
		kind = .picker
		controlView = AnyView(OptionPicker(name: name, value: value, options: Array(Value.allCases)))
		codeLiteral = { "." + String(describing: value.wrappedValue) }
	}

	/// A control row with a caller-supplied view — the escape hatch for types
	/// that are neither `Adjustable` nor `CaseIterable` enums, and for
	/// overriding the default control of one parameter.
	///
	/// `code` supplies the value's Swift literal for "Copy values as code";
	/// the default `String(describing:)` is readable but not guaranteed to be
	/// compilable source.
	@MainActor
	public init<Value, ControlBody: View>(
		_ name: String,
		_ value: Binding<Value>,
		kind: ControlKind = .custom,
		code: @escaping (Value) -> String = { String(describing: $0) },
		@ViewBuilder control: (Binding<Value>) -> ControlBody
	) {
		self.name = name
		self.kind = kind
		controlView = AnyView(control(value))
		codeLiteral = { code(value.wrappedValue) }
	}
}

/// Builds the `Subject(param: value, ...)` initializer string for the current
/// control values — the payload of "Copy values as code".
public func rehearsalCallCode(subject: String, controls: [ParameterControl]) -> String {
	let arguments = controls
		.map { "\($0.name): \($0.codeLiteral())" }
		.joined(separator: ", ")
	return "\(subject)(\(arguments))"
}
