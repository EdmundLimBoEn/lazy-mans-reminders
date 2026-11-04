# Decisions

- 2026-11-04: Keep integration in the existing clean tracked checkout; untracked .cursor/, .tf-run-watch*.log, ios/.asc/, ios/ExportOptions.plist are out of scope. All worker checkouts are tool-created worktrees.
- 2026-11-04: 30-category rubric with arithmetic mean and explicit evidence gaps. Ratings must remain honest.
- 2026-11-04: Try iOS 26.2 standard simulator runtime because the only installed runtime supports only Duo. Do not alter runtime compatibility metadata.
- 2026-11-04: No branding/copy changes and no shipping actions.

Written by gpt-6.1-sol in Codex on behalf of Edmund

- 2026-11-04 user addition: compare against paired Apple Notes and Reminders reference states; preserve independent layout. Require executable geometry/accessibility checks wherever measurable. Use iPhone 17 Pro for shared reference device.

- 2026-11-04: Authorized minimal Debug-only explicit demo guard in AuthManager initializer and inert demo app delegate to prevent auth restoration/network work. Normal Debug and Release behavior must remain unchanged.

- 2026-11-04: Stop device interactions after device_open rejected the created regular17 twice and refreshed inventory stayed stale. Do not bypass T3 with simctl UI, another session or another automation channel. Keep unvalidated harness branch unmerged.

- 2026-11-04: Resumed with shell-based xcodebuild test (authorized project test runner). It booted regular17; a subsequent device_list now discovers the simulator. Continue captures through device_open rather than bypassing prescribed UI tooling. Fix harness preflight to check deviceTypeIdentifier, not simulator display name.
