---
paths:
  - "**/*.swift"
  - "**/Package.swift"
  - "**/*.xcodeproj/**"
---

# Swift Development

## Concurrency (Swift 6)

- All code must be Swift 6 concurrency-safe: Sendable protocol, actor isolation, @MainActor
- Be cautious with @MainActor isolation, nonisolated contexts, and Sendable conformance
- When accessing @ObservableObject publishers (e.g. `$property`) from nonisolated context, restructure to avoid crossing isolation boundaries
- Prefer structured concurrency (async/await, TaskGroup) over callbacks
- Types crossing module boundaries must be public and Sendable
- After ANY concurrency-related changes, run a full build before considering the task done

## UI

- All UI should be built with SwiftUI
- When implementing new UI features, prefer the simplest approach first (e.g., shell out to existing system tools like `screencapture`, simple loops) rather than building custom overlays or complex UI from scratch. Ask before over-engineering

## General

- Use Swift 5.x syntax with swift-tools-version 5.9+
- Dependencies managed via Swift Package Manager
- Use `@MainActor` for all UI/AppKit code
- Vision framework calls should handle multiple recognition levels
- OCR operations should gracefully handle failures with user feedback via notifications

## Build Verification

- Always run `xcodebuild` (or the project's build command) after making changes
- Do NOT report completion until the build succeeds with zero errors
- Pay attention to warnings — especially concurrency warnings that will become errors
