# Apple reference captures

Target: the same regular iPhone 17 Pro simulator used for Notepad. Apple Reminders and Notes, in both light and dark. These are polish references, not layout templates. Demo content only, on a fresh isolated simulator, no Apple ID.

Required per app and appearance: list/top, list/bottom with a long seeded list, compose/keyboard, and a native sheet. Record exact device, runtime, app version, content/scroll position, SHA of each image and capture time in manifest.json. Empty and large-type references are useful additional evidence. Explicitly record missing states; do not substitute screenshots from another device or mockups.

Each round manifest maps each Notepad state to the nearest reference images. Where native app semantics differ (account/sign-in, ActivityKit), report the limits rather than claiming an exact match. Graders assess hierarchy, spacing, typography, system integration and polish independently of layout.

All interactions/captures use the T3 device_open returned agent-device session. Use device_screenshot to inspect. Do not use simctl screenshots or other sessions.

Status: pending compatible runtime installation. No reference images captured yet.

Written by gpt-6.1-sol in Codex on behalf of Edmund
