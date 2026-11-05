# Motion cleanup recheck: blocked before runtime

Branch `t3/verify-motion-settings-restore`, baseline `2427d4a` (contains parent test correction `3a83a33`). No production changes. Only AccessibilitySettingsUITests.swift adds native Settings values/debug-description attachments before and after configuration; keyboard/error assertions are unchanged. This instrumentation has not been runtime verified.

Read hillclimb/state.md and hillclimb/tasks/error-keyboard/README.md and the using-xcode-cli skill. Setup used this isolated worktree’s example-derived NotepadHillclimb config and xcodegen; dependencies resolved once into fresh `/tmp/hillclimb-motion-7915-DD`. Fresh unsigned arm64 Debug build-for-testing succeeded; build.json retains the exact command, timestamps and compiler diagnostics (five existing Swift warnings plus App Intents metadata warning). build-identity.json retains Swift source, app/test binary and exact generated xctestrun hashes/timestamps. No runtime diagnostics were collected because tests never ran. No Release/backend validation was run.

Exclusive original17: host `local`, UDID `78F5A64F-7B2E-4562-8EF9-10F3312CC694`. Owned device session `t3-e48b29d0d6e75634af0ed67b`. Native Motion snapshot actually read Reduce Motion=Off, Auto-Play Message Effects=On; other visible Motion switches: Dim Flashing Lights=Off, Auto-Play Animated Images=On, Auto-Play Video Previews=On, Prefer Non-Blinking Cursor=Off, Limit Frame Rate=Off. Original snapshot and unmodified screenshot retained. Reduce Transparency and Increase Contrast were not independently read before the tool failure. No setting toggles or appearance/text-size changes were performed. No app/demo Activity was launched.

## Retained attempts and required stop

Navigation to Display & Text Size failed:

`Error (COMMAND_FAILED): Ref @e11 needs a complete snapshot — the current frame only authorizes its emitted refs`

`Hint: Retry with the exact emitted ref @e11~s819642.`

Diagnostic ID `mw2jzpxw-45e1c20f`; request ccfc6bbd9de4cb50 retained. Followed that exact hint once. The retry failed:

`Error (COMMAND_FAILED): Ref @e11 was minted from a superseded snapshot generation`

`Hint: Ref @e11 was minted from snapshot s819642 but the session's ref frame is now s819643 — re-run snapshot -i.`

Diagnostic ID `mw2jzvws-d6057bf3`; request 0d0ce9f41157f561 retained. The first failed invocation also obtained a complete snapshot, which advanced the generation before the suggested exact retry. Both shell calls returned exit 0 despite the embedded device-command errors; they are failures, not passes.

Developer device instructions require stopping after advice fails once. No more UI actions, tests or cleanup were attempted. Device remains booted with Settings open at Accessibility and own session open. No shutdown or other session touched. Initial supplied light/Large state was not changed but final independent UI handback verification was not completed.

Preflight: NOT RUN (0 tests). Full291 suite: NOT RUN (0 tests). Eight combined cases, eight normal cases and44 raster gates: NOT RUN. No teardown-original==restored proof, runtime warning count, invalid-frame count or score is claimed. Parent restoration correction remains unverified. Existing K evidence is untouched and is not attributed to this revision. Required restoration gate is unverified, not passed.

Written by gpt-6.1-sol in Codex on behalf of Edmund
