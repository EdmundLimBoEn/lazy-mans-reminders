# Agent notes

## Branches

`dev` is the current working branch. Open feature and fix pull requests against `dev`.

`main` is the release branch. Ship by opening a pull request from `dev` into `main`, and merge it only when a release is intended.

The iOS TestFlight workflow runs on pushes to `main` and on `workflow_dispatch`. Merges into `dev` do not upload a TestFlight build.
