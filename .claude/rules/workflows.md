# Workflows

## CI / Build

- When fixing CI/build issues, always match the local development environment first (same Xcode version, same toolchain, same Go version) rather than downgrading project settings to fit CI constraints
- Do NOT downgrade swift-tools-version, Go version, or other project settings to fix CI — update the CI runner configuration instead
- After making code review fixes or multi-file changes, always run a full build/compile check before reporting completion. Do not assume edits compile cleanly

## Code Quality

- When refactoring logic (e.g., moving processing out of a loop, extracting functions), trace ALL code paths that invoke the moved logic — including fallback paths, error paths, and conditional branches — not just the primary path
- Before implementing a change, explicitly enumerate all call sites and code paths affected
- Verify each affected path still works after the change

## Release Management

Releases typically involve these steps (follow the existing pattern in the repo):

1. Analyze commits since last tag to draft changelog
2. Update CHANGELOG.md or release notes
3. Create git tag with version
4. Build release artifacts/binaries
5. Create GitHub release with artifacts attached
6. Update Homebrew formula with new version and SHA (if applicable)
7. Push all changes and tags
