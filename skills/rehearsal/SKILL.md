---
name: rehearsal
description: Integrate and use Rehearsal, a Swift package for interactive SwiftUI previews with an auto-generated control panel. Use when adding adjustable or tweakable parameters to a SwiftUI preview, making a preview interactive, rehearsing a view's states, or when the user mentions Rehearsal, Rehearse, or "knobs"/"controls" in previews.
---

# Rehearsal: interactive SwiftUI previews

Rehearsal wraps a view in `Rehearse` inside a regular `#Preview` and builds a
live control panel from inline `param(...)` declarations. Each `param` call
declares one adjustable parameter — a control appears in the panel, and the
call returns the parameter's current value. No macros, no code generation, no
transitive dependencies.

## Requirements

- iOS 16 / macOS 13 / visionOS 1 / Mac Catalyst 16.
- **No tvOS or watchOS.** Don't add `Rehearse` previews to files compiled for
  those platforms unless guarded with `#if os(...)`.
- Swift 6.0+.

## Installation

Add the package and product dependency:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/daneden/Rehearsal.git", from: "0.1.0"),
],
// in the target that contains the previews:
.target(name: "MyViews", dependencies: [
    .product(name: "Rehearsal", package: "Rehearsal"),
]),
```

In an Xcode app project, use **File > Add Package Dependencies…** instead and
add the `Rehearsal` library to the app target.

## Core pattern

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

- Write the `#Preview` literally — Xcode's canvas only discovers previews
  spelled as `#Preview` in source. Don't hide it behind helper functions or
  macros.
- Types are inferred from the default value and the parameter the result is
  passed to; `.compact`-style member shorthand works without annotations.
- The subject type (`MyCard.self`) supplies the panel title and the type name
  in the copied code snippet. Pass an explicit title with
  `Rehearse("My Card", MyCard.self) { ... }`.

## Supported parameter types and their controls

| Type | Control |
| --- | --- |
| `String` | Text field |
| `Int` | Stepper + slider (respects `range:`, default `0...100`) |
| `Double` | Slider (respects `range:`, default `0...1`) |
| `Bool` | Toggle |
| `Color` | Color picker |
| `CaseIterable & Hashable` enum | Picker (segmented for ≤ 3 cases, menu otherwise) |

Enums need no conformance — any `CaseIterable & Hashable` enum works.

## Rules of `param`

- Names must be unique within one `Rehearse` (duplicates assert in debug).
- Use the view's **real argument labels** as param names — they become the
  argument labels in the panel's "Copy values as code" output.
- Controls appear in call order; calls inside `if` branches come and go with
  the branch.
- Picker options must be distinct and must contain the default (asserted in
  debug).

## Overriding the control

`param(...)` picks the control from the value's type. Explicit variants
override it per parameter:

```swift
count: param.slider("count", range: 0...10, default: 3)   // Int as plain slider
count: param.stepper("count", default: 3)                 // Int as stepper only
badge: param.picker("badge", options: [.hidden, .new, .sale], default: .new)  // any Hashable
```

## Animating changes

Pass `animation:` to any `param` variant to animate the view whenever that
control changes the value:

```swift
style: param("style", default: .compact, animation: .spring(response: 0.4, dampingFraction: 0.75))
```

## Custom controls

Two escape hatches beyond `param.picker`:

- **One-off control** — any view driven by a `Binding<Value>`, with an
  optional `code:` closure for "Copy values as code":

  ```swift
  insets: param.custom("insets", default: EdgeInsets()) { value in
      InsetsEditor(insets: value)
  }
  ```

- **Reusable control for a type** — conform the type to `Adjustable` and every
  `param(...)` of that type gets it automatically.

## Reference

- Full API docs: https://daneden.github.io/Rehearsal/documentation/rehearsal/
- The package's `Examples/RehearsalExamples/MyCard.swift` demonstrates every
  supported parameter type, plus a hand-wired harness for full control over
  the state.
