Review changes using the external tool mpt. Here is a step-by-step instructions:

* Check if REVIEW_GUIDELINES.md exists in the project root. If it does, read it and incorporate the project-specific review criteria into the review prompt below.
* Gather reviews by running this command: mpt --git.diff --openai.enabled --google.enabled --anthropic.enabled --max-file-size=200000 --timeout=5m -p "Perform a comprehensive code review of these changes. Analyze the design patterns and architecture. Identify any security vulnerabilities or risks. Evaluate code readability, maintainability, and idiomatic usage. Suggest specific improvements where needed. {If REVIEW_GUIDELINES.md was found, append: Also evaluate against these project-specific criteria: <contents of REVIEW_GUIDELINES.md>}"
* Using the command's output, synthesize these reviews into a concise summary of the key issues and improvements.
* Validate the summary of actions with the user and proceed with fixing.
