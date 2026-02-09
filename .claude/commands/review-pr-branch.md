Review changes against main branch using the external tool mpt. Here is a step-by-step instructions:

* Gather reviews by running this command, substitude <branch> with user input in: git diff <branch> | mpt --openai.enabled --google.enabled --anthropic.enabled --timeout=5m --max-file-size=200000 -p "Perform a comprehensive code review of these changes. Analyze the design patterns and architecture. Identify any security vulnerabilities or risks. Evaluate code readability, maintainability, and idiomatic usage. Suggest specific improvements where needed.
* Using the command's output, synthesize these reviews into a concise summary of the key issues and improvements.
* Validate the summary of actions with the user and proceed with fixing.
