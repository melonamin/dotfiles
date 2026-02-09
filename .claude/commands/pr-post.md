Create draft of a blogpost. Here is a step-by-step instructions:

* Gather post ideas, substitude <current_branch> with current branch in git: mpt --git.branch <current_branch> --openai.enabled --google.enabled --anthropic.enabled --max-file-size=200000 --timeout=5m -p "Review the changes. Write a technical blogpost about how this feature came to be, why the implementation is the way it is and how we come to it. What were the inferior ways to do it. What we could do in the future".
* Using the command's output, create a your own post, using the best points from all of them.
* Output the result, both your version and all source versions, into a file in markdown
