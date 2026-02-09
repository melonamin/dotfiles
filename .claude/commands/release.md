Prepare and publish a release for the current project. Argument $ARGUMENTS is the version (e.g. "v1.2.0") or bump type (e.g. "patch", "minor", "major"). If empty, analyze commits to suggest the appropriate bump.

Follow these steps:

1. **Determine version**: If a specific version was given, use it. If a bump type was given (patch/minor/major), calculate the next version from the latest git tag. If neither, analyze commits since the last tag and suggest a version based on conventional commits / semantic versioning. Ask the user to confirm.

2. **Generate release notes**: Analyze all commits since the last git tag. Group them by category:
   - Features (feat:, add:)
   - Bug Fixes (fix:)
   - Improvements (refactor:, perf:, improve:)
   - Other notable changes
   Write concise, user-facing descriptions (not raw commit messages).

3. **Update changelog**: Look for CHANGELOG.md or docs/release-notes/ in the project. Update the appropriate file with the new version and release notes. Follow the existing format in the file. If no changelog exists, ask the user where to put release notes.

4. **Build verification**: Run the project's build command to ensure everything compiles cleanly. Do NOT proceed if the build fails.

5. **Create release commit and tag**: Stage the changelog changes, commit with message "Release <version>", and create an annotated git tag.

6. **Build release artifacts**: If the project has a build script for release binaries (check Makefile, justfile, Scripts/, .github/workflows/ for patterns), run it. For Go projects, build for common platforms (darwin/arm64, darwin/amd64, linux/amd64). For Swift/macOS projects, build the Release configuration.

7. **Create GitHub release**: Use `gh release create <tag> --title "<version>" --notes-file <tempfile>` with the release notes. Attach any built artifacts.

8. **Update Homebrew formula**: If a Homebrew formula exists (check for a Formula/ dir, homebrew-tap repo reference, or cask), update it with the new version and SHA256. Ask the user for confirmation before pushing to the tap repo.

9. **Summary**: Show the user what was done and what needs manual attention (e.g. pushing, App Store submission).

IMPORTANT: Ask for user confirmation before pushing tags, creating the GitHub release, and updating Homebrew. These are irreversible actions.
