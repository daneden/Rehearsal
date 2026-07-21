# Rehearsal

[![CI](https://github.com/daneden/Rehearsal/actions/workflows/ci.yml/badge.svg)](https://github.com/daneden/Rehearsal/actions/workflows/ci.yml)

Interactive SwiftUI previews with an auto-generated control panel. Declare the
adjustable parameters of a view inline — right where the values are used — and
Rehearsal builds the state, the live controls, and the wired-up preview. A
preview is where a view rehearses its states before going live in the app.

The preview shows the view on top and a scrollable control panel below, with a
**Copy values as code** button (copies a ready-to-paste initializer call like
`MyCard(title: "Hello", count: 3, ...)` reflecting the current values) and a
**Reset** button.

No macros, no code generation, no dependencies.

## Requirements

- iOS 17 / macOS 14
- Swift 6.0+

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/daneden/Rehearsal.git", from: "0.1.0"),
]
```

and add `Rehearsal` to your target's dependencies, or add it to an Xcode
project via **File > Add Package Dependencies…**.

## Usage

Wrap your view in `Rehearse` inside a regular `#Preview`. Each `param(...)`
call declares one parameter — a control appears in the panel, and the call
returns the parameter's current value:

```swift
import SwiftUI
import Rehearsal

#Preview("My Card") {
    Rehearse(MyCard.self) { param in
        MyCard(
            title: param("title", default: "Hello"),
            count: param("count", range: 0...10, default: 3),
            isOn: param("isOn", default: true),
            style: param("style", default: .compact)  // CaseIterable enum
        )
    }
}
```

Types are inferred — from the default value and from the parameter the result
is passed to, so even `.compact` and `.blue` resolve without annotations.
Because the value is returned where it's declared, there's no parameter list
to keep in sync with a closure signature.

The subject type (`MyCard.self`) supplies the panel title and the type name in
the copied code snippet; pass an explicit title with
`Rehearse("My Card", MyCard.self) { ... }`.

### Supported parameter types and their controls

| Type | Control |
| --- | --- |
| `String` | Text field |
| `Int` | Stepper + slider (respects `range:`, default `0...100`) |
| `Double` | Slider (respects `range:`, default `0...1`) |
| `Bool` | Toggle |
| `Color` | Color picker |
| `CaseIterable & Hashable` enum | Picker (segmented for ≤ 3 cases, menu otherwise) |

Enums need no conformance at all — any `CaseIterable & Hashable` enum works.

### Choosing the control

`param(...)` picks the control from the value's type. To override it for one
parameter, use the explicit variants:

```swift
count: param.slider("count", range: 0...10, default: 3)   // Int as plain slider
count: param.stepper("count", default: 3)                 // Int as stepper only
```

### Custom controls

Three escape hatches, from least to most involved:

- **An option list** — for enums that aren't `CaseIterable`, or any `Hashable`
  type with a meaningful set of values:

  ```swift
  badge: param.picker("badge", options: [.hidden, .new, .sale], default: .new)
  ```

- **A custom control for one parameter** — any view driven by a
  `Binding<Value>`, with an optional `code:` closure for "Copy values as
  code":

  ```swift
  insets: param.custom("insets", default: EdgeInsets()) { value in
      InsetsEditor(insets: value)
  }
  ```

- **A reusable control for a type** — conform the type to `Adjustable` and
  every `param(...)` of that type gets it automatically.

### Rules of `param`

- Names must be unique within one `Rehearse` (duplicates assert in debug and
  keep the first control).
- Controls appear in call order, and the panel reflects whatever was declared
  in the *current* render — calls inside `if` branches come and go with the
  branch.
- Names are used as argument labels in the copied code snippet, so use the
  view's real parameter names.
- Picker options must be distinct and contain the default (asserted in debug).

## Documentation

Full API documentation ships as a DocC catalog: **Product > Build
Documentation** in Xcode, or `swift package generate-documentation`.

## Examples

The `Examples/RehearsalExamples` target ships `MyCard`, a demo view exercising
every supported parameter type, plus a hand-wired harness for when you need
full control over the state. Open the package in Xcode and preview
`Examples/RehearsalExamples/MyCard.swift`.
