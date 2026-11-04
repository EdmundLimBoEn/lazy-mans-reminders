#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
python3 - "$root" <<'PY'
import pathlib, sys
root=pathlib.Path(sys.argv[1])
target=root/'ios/Config.xcconfig'
example=(root/'ios/Config.example.xcconfig').read_text().replace('systems.edmundlim.LazyMansReminders','systems.edmundlim.NotepadHillclimb')
if target.exists() and target.read_text() != example:
    sys.exit('Refusing to overwrite an existing config; use a dedicated worktree with no Config.xcconfig')
target.write_text(example)
PY
xcodegen generate --spec "$root/ios/project.yml"
