# Rehearsal — contributor and agent notes

Context that doesn't belong in the end-user README: architecture, design
history, and workflows for working on the package itself.

## Architecture

Runtime-only "knobs" API — no macros, no code generation.

| File | Contents |
| --- | --- |
| `Sources/Rehearsal/Rehearse.swift` | `Rehearse` view, `Parameters` callable, `ParameterValues` store |
| `Sources/Rehearsal/Adjustable.swift` | `Adjustable`/`RangeAdjustable` protocols, built-in conformances, `OptionPicker`, `ControlKind` |
| `Sources/Rehearsal/ParameterControl.swift` | Type-erased control row, `rehearsalCallCode` |
| `Sources/Rehearsal/ExplicitControls.swift` | `param.slider/stepper/picker/custom` overrides, shared `Int` row views, `optionCodeLiteral` |
| `Sources/Rehearsal/RehearsalHarness.swift` | Split layout, copy/reset buttons, pasteboard |

Key mechanics:

- **Value storage** is a name-keyed `[String: Any]` held in `@State`, wrapped
  in `ParameterValues` (`@unchecked Sendable`) so `Binding`s over it can be
  captured by `Binding`'s `@Sendable` accessors. Typed bindings cast per name;
  the casts are safe by construction — a slot is seeded from its param's
  default and only written through that param's typed control.
- **Registration happens during body evaluation** into a per-evaluation
  `Session` (a class created fresh each render). Unset names fall back to the
  default in the binding *getter* — never written eagerly, because state
  writes are illegal during body evaluation.
- **`CaseIterable` enums need no conformance**: `@_disfavoredOverload`
  fallbacks on `Parameters.callAsFunction` and `ParameterControl.init` handle
  them; an explicit `Adjustable` conformance wins when present. This overload
  trick is per-call-site — it's the reason the API is generic methods rather
  than anything pack-based.
- Control construction is `@MainActor` throughout (SDK 27's `View` protocol is
  `@MainActor`, so view memberwise inits are isolated).

## History: why there is no macro

The first iteration was a swift-syntax `#Rehearsal` declaration macro that
generated a `#Preview`. It was removed deliberately; don't reintroduce it
without reading this:

- Xcode's preview canvas only discovers previews spelled literally as
  `#Preview` in source. Macro-generated previews compile and register
  (PreviewRegistry symbols land in the binary) but never appear in the canvas.
- Nested macro expansion is hostile territory (verified on Swift 6.4 / Xcode
  27 beta): unique-named sibling declarations aren't resolvable from inside
  the nested `#Preview` expansion; the preview body builder rejects both local
  declarations and explicit `return`; attached macros (`@State`) don't expand
  inside doubly-nested macro output, and even plain local structs there fail
  to type-check while identical hand-written source compiles.
- A macro named `Rehearsal` shadows the *module* named `Rehearsal`, breaking
  module-qualified references in generated code.
- swift-syntax added minutes of clean-build time for every consumer.

The runtime API also removed the macro's ergonomic warts (name/order
duplication between a `Param` list and a closure signature).

## Platform scope

iOS 16 / macOS 13 / visionOS 1 / Mac Catalyst 16. The floor is set by the
control set, not by exotic API — the one iOS-17 API we used
(`Color.resolve(in:)`) was replaced with `UIColor`/`NSColor` component
extraction in `Color.codeLiteral`. tvOS and watchOS are deliberately out of
scope: tvOS has no `Slider`/`Stepper`/`ColorPicker`, watchOS lacks
`ColorPicker`, segmented pickers, and any pasteboard — supporting them means a
parallel control set, not a platforms-list edit. visionOS builds are verified
locally (`xcodebuild -destination 'generic/platform=visionOS'`); CI doesn't
cover visionOS because runner images don't reliably include its SDK.

## SDK and toolchain notes

- **SDK 27: `@State` is a macro** and suppresses synthesized initializers —
  views with `@State` need an explicit `init()` (see `HandWiredExample`).
  Initial values belong at the declaration; assigning `@State` in `init` is an
  anti-pattern.
- **CLI SwiftPM (beta) prints an "unhandled file" warning** for the `.docc`
  catalog; Xcode builds are clean. Don't `exclude:` the catalog — the DocC
  plugin stops seeing it and the curated landing page vanishes.

## Agent skill

`skills/rehearsal/SKILL.md` is an Agent Skill distilled from the README's
consumer-facing API docs — update it when the public API changes. The
`InstallRehearsalSkill` command plugin copies it into a consumer's
`.agents/skills/` (with a `.claude/skills/rehearsal` symlink for Claude
Code); it locates the skill via `#filePath` (command plugins
always compile from source in the checkout, and neither plugin context
exposes a dependency's checkout path), so moving `skills/` requires updating
the plugin.

## Validation philosophy

Type errors surface at the call site as missing overloads (no runtime type
registry). Debug-only assertions cover: duplicate param names, picker defaults
missing from `options`, duplicate picker options. `param.custom`'s default
`code:` is `String(describing:)` — readable, not guaranteed to be compilable
source.

## Workflows

- Tests: `swift test` (27 tests: control selection per type, `Parameters`
  registration/value flow, store round-trips, code-string generation).
- iOS build check: `xcodebuild build -scheme Rehearsal-Package -destination
  'generic/platform=iOS Simulator'`.
- Docs: `swift package generate-documentation --target Rehearsal` (catalog at
  `Sources/Rehearsal/Rehearsal.docc`).
- CI: `.github/workflows/ci.yml` runs both test and iOS-build jobs on
  `macos-latest` with the newest installed Xcode.
- A pre-commit swiftformat hook reformats staged Swift files (tabs,
  `public extension`, spaced range operators, strips redundant `@Suite`).
