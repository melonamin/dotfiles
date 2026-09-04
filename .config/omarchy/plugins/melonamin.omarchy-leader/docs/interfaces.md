# Visual interface API

Omarchy Leader interfaces are trusted QML components. They render a read-only
presentation model and do not own keyboard handling, navigation, timers, or
action execution.

Put an interface under:

```text
~/.config/omarchy/leader/interfaces/<id>/
├── manifest.json
└── Interface.qml
```

The manifest contract is:

```json
{
  "apiVersion": 1,
  "id": "example.radial",
  "name": "Radial",
  "entryPoint": "Radial.qml",
  "capabilities": ["compact"]
}
```

The entry point must be an `Item` with two required properties:

```qml
import QtQuick

Item {
  property var model
  property var theme

  implicitWidth: 500
  implicitHeight: 300
}
```

`model` contains:

- `active`, `armed`, and `phase`
- `path`, `choices`, and `typedKeys`
- `errorMessage` and `statusMessage`
- `currentId` and `revision`

`theme` contains stable surface colors, typography sizes, spacing, radius, and
the current Omarchy menu font. Interfaces should not import Omarchy's internal
`qs.Commons` module directly.

Interfaces execute as unsandboxed QML inside `omarchy-shell`. Install only code
you trust.
