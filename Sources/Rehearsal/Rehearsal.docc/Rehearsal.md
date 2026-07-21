# ``Rehearsal``

Interactive SwiftUI previews with an auto-generated control panel.

## Overview

A preview is where a view rehearses its states before going live in the app.
Wrap a view in ``Rehearse`` inside a regular `#Preview`, declare its
parameters inline with `param(...)` calls, and Rehearsal builds the state, the
live controls, and the wired-up preview — the view on top, a scrollable
control panel below, plus **Copy values as code** and **Reset** buttons.

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

Each `param(...)` call declares one parameter — registering a control chosen
from the value's type — and returns the parameter's current value. `String`,
`Int`, `Double`, `Bool`, `Color`, and `CaseIterable` enums work out of the
box; conform your own types to ``Adjustable``, or supply per-parameter
controls with ``Parameters/picker(_:options:default:)`` and
``Parameters/custom(_:default:code:control:)``.

## Topics

### Essentials

- ``Rehearse``
- ``Parameters``

### Supporting your own types

- ``Adjustable``
- ``RangeAdjustable``

### Building blocks

- ``ParameterControl``
- ``ControlKind``
- ``RehearsalHarness``
- ``rehearsalCallCode(subject:controls:)``
