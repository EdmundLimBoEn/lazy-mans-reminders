#!/usr/bin/env bash
set -euo pipefail

# Retry dependency downloads separately so test failures are never retried.
for attempt in 1 2 3; do
  if deno cache supabase/functions/_shared/*_test.ts supabase/functions/delete-account/*_test.ts; then
    exit 0
  fi
  if [ "$attempt" -lt 3 ]; then
    sleep $((attempt * 5))
  fi
done

echo 'Deno test dependency downloads failed after 3 attempts.' >&2
exit 1
