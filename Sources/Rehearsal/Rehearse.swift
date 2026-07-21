import SwiftUI

/// Heterogeneous parameter-value storage, keyed by parameter name.
///
/// Wrapping `[String: Any]` in a Sendable struct lets `Binding`s over it be
/// captured by `Binding`'s `@Sendable` accessors. Values are only touched on
/// the main actor (SwiftUI state), hence `@unchecked`.
struct ParameterValues: @unchecked Sendable {
	var storage: [String: Any] = [:]
}

/// Carries a control's default value into `Binding`'s `@Sendable` accessors.
/// Defaults are only read on the main actor, hence `@unchecked`.
private struct UncheckedBox<Value>: @unchecked Sendable {
	let value: Value
}

/// The callable ``Rehearse`` hands to its content closure. Each call declares
/// one adjustable parameter — registering its control row in the panel — and
/// returns the parameter's current value:
///
/// ```swift
/// Rehearse(MyCard.self) { param in
///     MyCard(
///         title: param("title", default: "Hello"),
///         count: param("count", range: 0...10, default: 3)
///     )
/// }
/// ```
@MainActor
public struct Parameters {
	/// Collects the control rows declared during one body evaluation.
	final class Session {
		var controls: [ParameterControl] = []
		var names: Set<String> = []
	}

	let session: Session
	let values: Binding<ParameterValues>

	/// Declares an adjustable parameter and returns its current value.
	///
	/// The control is chosen by `Value`'s ``Adjustable`` conformance: a text
	/// field for `String`, a toggle for `Bool`, and so on. Pass `animation:`
	/// to animate the view whenever the control changes this value.
	public func callAsFunction<Value: Adjustable>(
		_ name: String,
		default defaultValue: Value,
		animation: Animation? = nil
	) -> Value {
		declare(ParameterControl(name, binding(name, default: defaultValue, animation: animation)), name, default: defaultValue)
	}

	/// Declares a numeric parameter whose control is constrained to `range`,
	/// and returns its current value.
	public func callAsFunction<Value: RangeAdjustable>(
		_ name: String,
		range: ClosedRange<Value>,
		default defaultValue: Value,
		animation: Animation? = nil
	) -> Value {
		declare(ParameterControl(name, binding(name, default: defaultValue, animation: animation), range: range), name, default: defaultValue)
	}

	/// Declares an enum parameter rendered as a picker over all cases, and
	/// returns its current value.
	///
	/// This is the fallback for `CaseIterable` enums without an ``Adjustable``
	/// conformance, so plain enums work unmodified. Disfavored so that a type
	/// conforming to both resolves to its own conformance.
	@_disfavoredOverload
	public func callAsFunction<Value: CaseIterable & Hashable>(
		_ name: String,
		default defaultValue: Value,
		animation: Animation? = nil
	) -> Value where Value.AllCases: RandomAccessCollection {
		declare(ParameterControl(name, binding(name, default: defaultValue, animation: animation)), name, default: defaultValue)
	}

	/// Unset names fall back to the default in the getter rather than being
	/// written eagerly — registration happens during body evaluation, where
	/// state writes are not allowed. A non-nil `animation` wraps the setter
	/// so control changes animate the rehearsed view.
	func binding<Value>(_ name: String, default defaultValue: Value, animation: Animation? = nil) -> Binding<Value> {
		let values = values
		let fallback = UncheckedBox(value: defaultValue)
		let base = Binding(
			get: { values.wrappedValue.storage[name] as? Value ?? fallback.value },
			set: { values.wrappedValue.storage[name] = $0 }
		)
		return animation.map { base.animation($0) } ?? base
	}

	func currentValue<Value>(_ name: String, default defaultValue: Value) -> Value {
		values.wrappedValue.storage[name] as? Value ?? defaultValue
	}

	/// Registers `control` under `name` and returns the parameter's current
	/// value — the shared tail of every declaration method.
	func declare<Value>(_ control: ParameterControl, _ name: String, default defaultValue: Value) -> Value {
		record(control, named: name)
		return currentValue(name, default: defaultValue)
	}

	func record(_ control: ParameterControl, named name: String) {
		guard session.names.insert(name).inserted else {
			assertionFailure("Rehearse: duplicate param name \"\(name)\"")
			return
		}
		session.controls.append(control)
	}
}

/// An interactive preview harness: the rehearsed view on top and an
/// auto-generated control panel below — one control per `param(...)` call —
/// plus "Copy values as code" and "Reset" buttons.
///
/// Use inside a `#Preview`:
///
/// ```swift
/// #Preview("My Card") {
///     Rehearse(MyCard.self) { param in
///         MyCard(
///             title: param("title", default: "Hello"),
///             count: param("count", range: 0...10, default: 3),
///             isOn: param("isOn", default: true),
///             style: param("style", default: .compact)  // CaseIterable enum
///         )
///     }
/// }
/// ```
///
/// The subject type is used for the panel title (when no explicit title is
/// given) and for the `MyCard(...)` snippet "Copy values as code" produces.
public struct Rehearse<Content: View>: View {
	private let title: String?
	private let subjectName: String
	private let splitOrientation: RehearsalSplitOrientation
	private let content: @MainActor (Parameters) -> Content

	@State private var values = ParameterValues()

	/// Creates a rehearsal for `subject`, titling the control panel with the
	/// type's name.
	public init(
		_ subject: Any.Type,
		splitOrientation: RehearsalSplitOrientation = .vertical,
		@ViewBuilder content: @escaping @MainActor (Parameters) -> Content
	) {
		title = nil
		subjectName = String(describing: subject)
		self.splitOrientation = splitOrientation
		self.content = content
	}

	/// Creates a rehearsal for `subject` with an explicit control-panel title.
	public init(
		_ title: String,
		_ subject: Any.Type,
		splitOrientation: RehearsalSplitOrientation = .vertical,
		@ViewBuilder content: @escaping @MainActor (Parameters) -> Content
	) {
		self.title = title
		subjectName = String(describing: subject)
		self.splitOrientation = splitOrientation
		self.content = content
	}

	public var body: some View {
		let params = Parameters(session: .init(), values: $values)
		let rehearsed = content(params)
		return RehearsalHarness(
			title: title ?? subjectName,
			subjectName: subjectName,
			controls: params.session.controls,
			reset: { values.storage = [:] },
			splitOrientation: splitOrientation
		) {
			rehearsed
		}
	}
}
