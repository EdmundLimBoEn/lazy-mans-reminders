# Notepad UI hill climb: progress report

Status: resumed. Simulator access recovered after XCTest booted the standard device. Existing runtime suite: 247 passed; composer field target fails at 22pt height; long scrolling test interrupted and being bounded before rerun. Target >=9/10 from sol/high, astra/high and Opus 5.5/medium has NOT been achieved or evaluated. No screenshot score round exists.

## Start and end scores

All 30 categories in rubric.md remain ungraded for all three models. No before/after pairs exist because T3 cannot open the created regular iPhone 17 Pro. Reference images are pending too. scores.json records the missing evidence and a failed completion gate. No scores have been fabricated.

## Completed work

Integration hillclimb/ui created from origin/main 5fc4cbc and pushed. Tracking, 30-category rubric, Apple reference protocol and machine-readable score validator committed. Validator exercised with synthetic accepted/rejected packets. User's preexisting untracked files preserved.

Prepared, unmerged branch hillclimb/capture-harness, commit f0e4f513f9df290f96a0f7c6fdb0d5d533888241, contains offline Debug fixtures, actual UI measurement probes, UI tests, capture/setup/check scripts. Worker reports Debug build-for-testing, Release build and 23 Python iOS checks passed. These are compilation/source checks, not simulator runtime evidence. XCTest, geometry assertions, screenshots and fixture isolation at runtime remain unvalidated. No production UI fix merged.

Installed standard iOS 26.2 runtime and created regular Hillclimb iPhone 17 Pro, UUID 78F5A64F-7B2E-4562-8EF9-10F3312CC694. T3 device_list still lists only Duo devices; device_open twice returned “No device … on This machine … Call device_list for current ids.” The prescribed inventory refresh did not fix it. Device rules require stopping rather than bypassing this failure.

## Merged changes

Tracking and scoring infrastructure only. Capture harness intentionally remains unmerged until runtime verification. No PR to main, deployment, App Store or TestFlight action.

## Installation on a phone

There is no validated hillclimb UI build to install yet. After completing capture/test gates and merging passing worker changes to hillclimb/ui: open the generated ios/LazyMansReminders.xcodeproj in Xcode, select hillclimb/ui, use your existing private Config.xcconfig and development signing team, choose a connected trusted iPhone, then Build and Run. Do not use the isolated screenshot configuration for normal account testing. No upload or distribution step is required or authorized. Hardware sign-in, notifications and Live Activity behavior still need device verification.

## Resume

Device discovery and opening now work. Continue reference captures and bounded geometry validation. Capture Apple reference pairs, validate and merge the prepared harness, capture Notepad baseline, then run independent graders and the fix/recheck loop. Native Live Activity capture is not yet supported by the offline fixture and remains an explicit evidence gap. Codex quota was not available through the exposed tool catalog; inspect limits before the first rating round.

Written by gpt-6.1-sol in Codex on behalf of Edmund
