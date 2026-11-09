# Round 3 isolated recheck

Production grading source remains `6959de17bb4d74fa1518914988645a3ea0313a68`. Validation started at `7561336`; keyboard test revision is `542b9f7` (exact file SHA256 in hash-proof.json). No production edits. Historical failed baseline remains in ../baseline-failure.md and ../combined-summary.json.

Setup: `bash scripts/hillclimb/setup.sh` generated this checkout’s Config.xcconfig from its tracked example and ran xcodegen. Fresh DD `/tmp/notepad-round3-recheck-86f22b1d-dd`; disk checked before creation (11 GiB available). `python3 hillclimb/validation/round3/recheck/run-validation.py setup` performed the only package resolution. Debug: same command with `Debug`; exact commands, timestamps, exit status and observed build diagnostics are in resolve.json/build-Debug.json. All subsequent build/test commands prohibit automatic package resolution and package updates.

Run each exact matrix with `python3 hillclimb/validation/round3/recheck/run-validation.py matrix1` (then matrix2 and matrix3 only after each prior pass); collect with `python3 hillclimb/validation/round3/recheck/collect.py matrix1` etc. `verify-matrices.py` checks actual activity capture names and subsequent 95% Done and 5% alternate edge taps. Full suite uses mode `combined`, with no test filter. Every test command uses the exact generated xctestrun, original17, no parallelism, 180/240-second timeouts and diagnostics collection never. No quiescence, warning, dismissal or geometry behavior is disabled. Generated xctestrun SHA and fresh arm64 binary hashes are recorded separately.

Historical Release build and 52+4 backend test results are reused only because all production and backend inventory hashes match. No fresh Release or backend execution is claimed. New iOS Python run: 23 passed. All 102 historical image hashes verified intact. Recheck captures, operations and manifest are under ../../../rounds/3/recheck/; original images are preserved. Apple reference limitations, including no sign-in auth reference, remain.

All result bundles are retained under /tmp/notepad-round3-recheck-86f22b1d-<mode>.xcresult. JSON summaries, full test trees, keyboard activities, legacy issues and start/end-scoped unified logs are retained here. Other runtime/system/compiler diagnostics are reported honestly; zero invalid-frame events is not a claim of globally silent logs.

Written by gpt-6.1-sol in Codex on behalf of Edmund

The independently built Debug executable is not byte-identical to the historical binary. binary-comparison.json retains both actual hashes. Reuse is justified by exact production inputs, not a fabricated binary-equality claim.
