Run an iterative build-fix loop until the project compiles and tests pass. Argument $ARGUMENTS is the command to run (e.g. "xcodebuild -scheme TRex build", "go build ./...", "yarn typecheck"). If empty, detect the project type and use the appropriate build command.

Follow this loop:

1. **Run the command** and capture all output (stdout and stderr).

2. **Analyze the output**:
   - If the command succeeded (exit code 0) with no errors or warnings, report success and stop.
   - If it failed, analyze EVERY error message carefully.

3. **Fix the errors**:
   - For each error, identify the root cause in the source code.
   - Apply the MINIMAL fix — do not refactor working code, do not change architecture.
   - For Swift concurrency errors, classify each as: @MainActor isolation, Sendable conformance, nonisolated access, or actor reentrancy, and apply the standard fix pattern.
   - For Go errors, check imports, types, and function signatures.
   - For TypeScript errors, check types, imports, and null safety.

4. **Re-run the command** to verify fixes. Go back to step 2.

5. **Escalation**: If you hit the SAME error 3 times in a row and cannot resolve it, STOP and report:
   - What the error is
   - What you tried
   - Why it's not working
   - Ask the user for guidance

RULES:
- Maximum 10 iterations. If not clean after 10, stop and report remaining issues.
- Do NOT ask for permission on each iteration — run autonomously until clean or stuck.
- Do NOT make unrelated changes. Only fix what the error output tells you to fix.
- After success, show a summary: how many iterations, what was fixed.
