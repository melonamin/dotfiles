#!/bin/bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$repo"

required=(
  manifest.json Compose.qml Service.qml ComposeModel.js SourceLoader.qml
  components/DiagnosticsView.qml components/KeyChip.qml components/QuickView.qml
  components/RuleEditor.qml components/RuleRow.qml components/StudioView.qml
  hypr/compose.lua scripts/compose-file scripts/compose-insert scripts/compose-sources
  scripts/generate-keysyms data/keysyms.tsv
  tests/model.test.js tests/keysym-differential.test.js tests/sources.test.js
  tests/transaction.test.sh tests/insert.test.sh tests/integration.sh
  README.md LICENSE preview.png
)
for path in "${required[@]}"; do [[ -e $path ]] || { echo "missing required file: $path" >&2; exit 1; }; done

jq -e '
  .schemaVersion == 1 and
  .id == "melonamin.compose" and
  .name == "Compose" and
  .version == "0.1.0" and
  .author == "melonamin" and
  .homepage == "https://github.com/melonamin/omarchy-compose" and
  .license == "MIT" and
  .keepLoaded == true and
  (.kinds | sort) == (["overlay", "service"] | sort) and
  .entryPoints.service == "Service.qml" and
  .entryPoints.overlay == "Compose.qml"
' manifest.json >/dev/null

for script in scripts/compose-file scripts/compose-insert scripts/compose-sources tests/static.sh tests/transaction.test.sh tests/insert.test.sh tests/integration.sh; do
  [[ -x $script ]] || { echo "script is not executable: $script" >&2; exit 1; }
  bash -n "$script"
done
[[ -x scripts/generate-keysyms ]] || { echo "script is not executable: scripts/generate-keysyms" >&2; exit 1; }
node --check scripts/generate-keysyms
luac -p hypr/compose.lua
node --check ComposeModel.js

shell_root=${OMARCHY_PATH:-$HOME/.local/share/omarchy}/shell
[[ -d $shell_root ]] || { echo "Omarchy shell QML imports not found: $shell_root" >&2; exit 1; }
qmllint -I "$shell_root" Compose.qml Service.qml SourceLoader.qml components/*.qml

if rg -n '/home/sasha|Developer/github.com/melonamin/omarchy-compose|file://' --glob '!docs/plans/**' --glob '!tests/static.sh' --glob '!tests/integration.sh' .; then
  echo "runtime contains a hard-coded checkout path" >&2
  exit 1
fi

if rg -n '\b(curl|wget|npm|pnpm|yarn|pip|uv add|git clone)\b' \
    Compose.qml Service.qml SourceLoader.qml ComposeModel.js components scripts hypr; then
  echo "runtime contains undeclared network or package-install behavior" >&2
  exit 1
fi

rg -q 'stdinEnabled: true' Compose.qml
rg -q 'cat > "\$payload"|read -r encoded_payload' scripts/compose-insert
! rg -n 'wl-copy[^<\n]*"\$payload"|wtype[^<\n]*"\$payload"' scripts/compose-insert
rg -q 'manifest\.__sourceDir' Service.qml Compose.qml
rg -q 'WlrLayershell\.namespace: "melonamin-compose"' Compose.qml
rg -q 'target: "compose"' Service.qml
rg -q 'Compose: Quick picker' Service.qml hypr/compose.lua
rg -q 'model: root\.watchedPaths' SourceLoader.qml
rg -q 'includes\[includeIndex\]\.resolved' SourceLoader.qml
rg -q 'rootSource\(\)\.unreadableRoot' Compose.qml
rg -q 'return Qt\.btoa\(String\(value || ""\)\)' Compose.qml
rg -Uq '(?s)function acceptGraph\(nextGraph\).*confirmPurpose === "delete".*confirmDialog\.opened = false.*deleteTarget = null' Compose.qml
rg -Uq '(?s)var snapshot = root\.rootSource\(\).*result\.digest !== snapshot\.digest.*sourceLoader\.reload\(\)' Compose.qml
rg -q 'resultString: resultStringPresent \? outputField\.text : null' components/RuleEditor.qml
rg -q 'eventModifiers: modifiers' components/RuleEditor.qml
rg -q 'qtModifiersToCompose\(mapped\.modifiers\)' components/RuleEditor.qml
rg -q 'draftChanged\(rawField\.text\)' components/RuleEditor.qml
rg -q 'onEditorDraftChanged: rawRule => root\.draftRaw = rawRule' Compose.qml
rg -q 'dirty && ComposeModel\.rootContentChanged\(graph, nextGraph\)' Compose.qml
rg -q 'busy: root\.busy' Compose.qml
rg -q 'enabled: !busy' components/StudioView.qml
rg -q 'ComposeModel\.replaceLocalDefinitions' Compose.qml
rg -q 'ComposeModel\.moveRuleToLocalSection' Compose.qml
rg -q 'conflict\.prefixes\.length' Compose.qml
rg -q 'confirmPurpose = "apply"' Compose.qml
rg -q 'limit: mode === "studio" \? graph\.rules\.length : 200' Compose.qml
rg -q 'groupOutputs: mode === "quick"' Compose.qml
rg -q 'excludeOutputs: mode === "quick" \? emojiOutputs : null' Compose.qml
rg -q '/shell/plugins/emojis/emojis\.json' Compose.qml
rg -q 'function trieNode' ComposeModel.js
rg -q 'alternativeCount' components/RuleRow.qml
rg -q 'function overlayDiagnostics' Compose.qml
rg -q 'onInspectWinnerRequested: rule => root\.inspectWinner\(rule\)' Compose.qml
rg -q 'property bool canSave: false' components/RuleEditor.qml
rg -q 'readonly property var chooserSuggestions' components/RuleEditor.qml
rg -q 'text: "Per-event modifiers"' components/RuleEditor.qml
rg -q 'enabled: root\.canSave' components/RuleEditor.qml
rg -q 'flock -x "\$lock_fd"' scripts/compose-file
rg -q 'result_revision=' scripts/compose-file
rg -q 'omarchy-compose-integration-terminal' tests/integration.sh
rg -q 'Compose insertion integration' tests/integration.sh
tests/insert.test.sh

printf '%s\n' 'static tests: ok'
