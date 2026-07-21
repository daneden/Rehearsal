@testable import Rehearsal
import SwiftUI
import Testing

private enum Fruit: CaseIterable, Hashable {
	case apple, banana, cherry
}

/// Exercises the constrained Adjustable conformance for CaseIterable enums.
private enum Theme: CaseIterable, Hashable, Adjustable {
	case light, dark
}

@MainActor
struct ControlSelectionTests {
	@Test func stringUsesTextField() {
		#expect(ParameterControl("title", .constant("Hello")).kind == .textField)
	}

	@Test func boolUsesToggle() {
		#expect(ParameterControl("isOn", .constant(true)).kind == .toggle)
	}

	@Test func intUsesStepper() {
		#expect(ParameterControl("count", .constant(3)).kind == .stepper)
		#expect(ParameterControl("count", .constant(3), range: 0 ... 10).kind == .stepper)
	}

	@Test func doubleUsesSlider() {
		#expect(ParameterControl("progress", .constant(0.5)).kind == .slider)
		#expect(ParameterControl("progress", .constant(0.5), range: 0 ... 1).kind == .slider)
	}

	@Test func colorUsesColorPicker() {
		#expect(ParameterControl("tint", .constant(Color.red)).kind == .colorPicker)
	}

	@Test func plainEnumUsesPicker() {
		#expect(ParameterControl("fruit", .constant(Fruit.apple)).kind == .picker)
	}

	@Test func adjustableEnumUsesPicker() {
		#expect(Theme.controlKind == .picker)
		#expect(ParameterControl("theme", .constant(Theme.dark)).kind == .picker)
	}
}

@MainActor
struct ParametersTests {
	@Test func registersControlsInDeclarationOrder() {
		let params = Parameters(session: .init(), values: .constant(ParameterValues()))
		_ = params("title", default: "Hello")
		_ = params("count", range: 0 ... 10, default: 3)
		_ = params("fruit", default: Fruit.apple)
		#expect(params.session.controls.map(\.name) == ["title", "count", "fruit"])
		#expect(params.session.controls.map(\.kind) == [.textField, .stepper, .picker])
	}

	@Test func returnsDefaultsWhenUnset() {
		let params = Parameters(session: .init(), values: .constant(ParameterValues()))
		#expect(params("title", default: "Hello") == "Hello")
		#expect(params("isOn", default: true) == true)
		#expect(params("fruit", default: Fruit.banana) == .banana)
	}

	@Test func returnsStoredValueWhenSet() {
		let values = ParameterValues(storage: ["title": "Hi", "count": 7])
		let params = Parameters(session: .init(), values: .constant(values))
		#expect(params("title", default: "Hello") == "Hi")
		#expect(params("count", range: 0 ... 10, default: 3) == 7)
	}

	@Test func controlCodeLiteralReadsStoredValue() {
		let values = ParameterValues(storage: ["title": "Hi"])
		let params = Parameters(session: .init(), values: .constant(values))
		_ = params("title", default: "Hello")
		#expect(params.session.controls.first?.codeLiteral() == "\"Hi\"")
	}
}

/// Deliberately not CaseIterable — exercises `picker(_:options:default:)`.
private enum Grade: Hashable {
	case pass, fail
}

@MainActor
struct ExplicitControlTests {
	@Test func overridesControlKind() {
		let params = Parameters(session: .init(), values: .constant(ParameterValues()))
		_ = params.slider("count", range: 0 ... 10, default: 3)
		_ = params.stepper("steps", default: 1)
		_ = params.slider("opacity", range: 0 ... 1, default: 0.5)
		#expect(params.session.controls.map(\.kind) == [.slider, .stepper, .slider])
	}

	@Test func pickerWorksWithoutCaseIterable() {
		let params = Parameters(session: .init(), values: .constant(ParameterValues()))
		let grade = params.picker("grade", options: [Grade.pass, .fail], default: .fail)
		#expect(grade == .fail)
		#expect(params.session.controls.first?.kind == .picker)
		#expect(params.session.controls.first?.codeLiteral() == ".fail")
	}

	@Test func animatedParamsRegisterAndReturnValues() {
		let params = Parameters(session: .init(), values: .constant(ParameterValues()))
		#expect(params("isOn", default: true, animation: .default) == true)
		#expect(params("count", range: 0 ... 10, default: 3, animation: .default) == 3)
		#expect(params.picker("grade", options: [Grade.pass, .fail], default: .pass, animation: .default) == .pass)
		#expect(params.session.controls.map(\.kind) == [.toggle, .stepper, .picker])
	}

	@Test func customControlUsesProvidedViewAndCode() {
		struct Insets: Equatable {
			var top = 4.0
		}
		let params = Parameters(session: .init(), values: .constant(ParameterValues()))
		let insets = params.custom("insets", default: Insets(), code: { "Insets(top: \($0.top))" }) { value in
			Slider(value: value.top, in: 0 ... 20)
		}
		#expect(insets == Insets())
		#expect(params.session.controls.first?.kind == .custom)
		#expect(params.session.controls.first?.codeLiteral() == "Insets(top: 4.0)")
	}
}

@MainActor
struct CodeGenTests {
	@Test func stringLiteralIsQuotedAndEscaped() {
		#expect("Hello".codeLiteral == "\"Hello\"")
		#expect("say \"hi\"\n\tnow \\ ok".codeLiteral == "\"say \\\"hi\\\"\\n\\tnow \\\\ ok\"")
	}

	@Test func numericAndBoolLiterals() {
		#expect(3.codeLiteral == "3")
		#expect((-7).codeLiteral == "-7")
		#expect(0.5.codeLiteral == "0.5")
		#expect(3.0.codeLiteral == "3.0")
		#expect(true.codeLiteral == "true")
		#expect(false.codeLiteral == "false")
	}

	@Test func colorLiteralUsesResolvedComponents() {
		let color = Color(red: 0.5, green: 0.25, blue: 1, opacity: 1)
		#expect(color.codeLiteral == "Color(red: 0.5, green: 0.25, blue: 1, opacity: 1)")
	}

	@Test func enumLiteralIsLeadingDotCase() {
		#expect(Theme.dark.codeLiteral == ".dark")
		let plainEnum = ParameterControl("fruit", .constant(Fruit.banana))
		#expect(plainEnum.codeLiteral() == ".banana")
	}

	@Test func callCodeJoinsAllParameters() {
		let controls = [
			ParameterControl("title", .constant("Hello")),
			ParameterControl("count", .constant(3), range: 0 ... 10),
			ParameterControl("isOn", .constant(true)),
			ParameterControl("style", .constant(Fruit.cherry)),
		]
		#expect(
			rehearsalCallCode(subject: "MyCard", controls: controls)
				== "MyCard(title: \"Hello\", count: 3, isOn: true, style: .cherry)"
		)
	}

	@Test func callCodeWithNoParameters() {
		#expect(rehearsalCallCode(subject: "MyCard", controls: []) == "MyCard()")
	}

	@Test func harnessCodeStringUsesSubjectAndControls() {
		let harness = RehearsalHarness(
			title: "My Card",
			subjectName: "MyCard",
			controls: [ParameterControl("title", .constant("Hello"))],
			reset: {}
		) {
			EmptyView()
		}
		#expect(harness.codeString == "MyCard(title: \"Hello\")")
	}

	@Test func adjustableOptionsUseTheirOwnLiteral() {
		let params = Parameters(session: .init(), values: .constant(ParameterValues()))
		_ = params.picker("count", options: [1, 2, 3], default: 2)
		#expect(params.session.controls.first?.codeLiteral() == "2")
	}

	@Test func customControlDefaultsToDescribingCode() {
		let params = Parameters(session: .init(), values: .constant(ParameterValues()))
		_ = params.custom("count", default: 5) { _ in EmptyView() }
		#expect(params.session.controls.first?.codeLiteral() == "5")
	}
}

/// A reference box so tests can observe writes made through bindings.
private final class ValueBox: @unchecked Sendable {
	var values: ParameterValues

	init(_ storage: [String: Any] = [:]) {
		values = ParameterValues(storage: storage)
	}

	var binding: Binding<ParameterValues> {
		Binding(get: { self.values }, set: { self.values = $0 })
	}
}

@MainActor
struct ValueStoreTests {
	@Test func controlBindingWritesReachTheStore() {
		let box = ValueBox()
		let params = Parameters(session: .init(), values: box.binding)
		let title = params.binding("title", default: "Hello")
		#expect(title.wrappedValue == "Hello")
		title.wrappedValue = "Changed"
		#expect(box.values.storage["title"] as? String == "Changed")
		#expect(params.currentValue("title", default: "Hello") == "Changed")
	}

	@Test func animatedBindingWritesReachTheStore() {
		let box = ValueBox()
		let params = Parameters(session: .init(), values: box.binding)
		let title = params.binding("title", default: "Hello", animation: .default)
		title.wrappedValue = "Changed"
		#expect(box.values.storage["title"] as? String == "Changed")
	}

	@Test func clearingTheStoreRestoresDefaults() {
		let box = ValueBox(["count": 9])
		let params = Parameters(session: .init(), values: box.binding)
		#expect(params.currentValue("count", default: 3) == 9)
		box.values.storage = [:]
		#expect(params.currentValue("count", default: 3) == 3)
	}

	@Test func mismatchedStoredTypeFallsBackToDefault() {
		let box = ValueBox(["count": "not an Int"])
		let params = Parameters(session: .init(), values: box.binding)
		#expect(params.currentValue("count", default: 3) == 3)
	}

	@Test func numericDefaultRanges() {
		#expect(Int.defaultRange == 0 ... 100)
		#expect(Double.defaultRange == 0 ... 1)
	}
}
