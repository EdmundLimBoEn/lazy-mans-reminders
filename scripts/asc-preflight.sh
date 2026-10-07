#!/usr/bin/env bash
# Read-only App Store Connect preflight for Lazy Man's Reminders 1.0.
# Prints a pass/fail list for the deploy bot.
#
# Never submits. Never mutates App Store Connect. Do not call:
#   asc submit, asc publish, asc review submissions-submit,
#   asc review submissions-create, asc versions attach-build,
#   asc app-setup info set, asc apps info edit, asc localizations update,
#   asc pricing availability edit, asc screenshots upload, asc screenshots apply.
set -euo pipefail

APP_ID="${ASC_APP_ID:-6799138197}"
VERSION="${ASC_VERSION:-1.0}"
PLATFORM="${ASC_PLATFORM:-IOS}"
export ASC_NO_UPDATE="${ASC_NO_UPDATE:-1}"

usage() {
  cat <<'EOF'
Usage: scripts/asc-preflight.sh

Read-only App Store Connect checks for app 6799138197 version 1.0.
Never submits. Extra arguments are rejected so this cannot be turned into a submit.

Environment:
  ASC_APP_ID     default 6799138197
  ASC_VERSION    default 1.0
  ASC_PLATFORM   default IOS
EOF
}

for arg in "$@"; do
  case "${arg}" in
    -h|--help)
      usage
      exit 0
      ;;
    *submit*|*publish*)
      echo "This script is read-only and refuses submit/publish arguments: ${arg}" >&2
      exit 2
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to parse asc JSON." >&2
  exit 1
fi

pass_count=0
fail_count=0
results=()

record() {
  local status="$1"
  local name="$2"
  local detail="${3:-}"
  results+=("${status}|${name}|${detail}")
  case "${status}" in
    PASS) pass_count=$((pass_count + 1)) ;;
    *) fail_count=$((fail_count + 1)) ;;
  esac
}

json_query() {
  local query="$1"
  python3 -c '
import json, sys

query = sys.argv[1]
raw = sys.stdin.read().strip()
if not raw:
    raise SystemExit("empty JSON")
obj = json.loads(raw)

def walk_items(value):
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        data = value.get("data")
        if isinstance(data, list):
            return data
        if isinstance(data, dict):
            return [data]
        if any(k in value for k in ("id", "attributes", "versionString", "buildId")):
            return [value]
    return []

def attrs(item):
    if not isinstance(item, dict):
        return {}
    nested = item.get("attributes")
    if isinstance(nested, dict):
        merged = dict(nested)
        merged.setdefault("id", item.get("id"))
        return merged
    return item

def text(*values):
    for value in values:
        if value is None:
            continue
        rendered = str(value).strip()
        if rendered and rendered.lower() not in ("none", "null"):
            return rendered
    return ""

items = walk_items(obj)

if query == "version_id":
    for item in items:
        a = attrs(item)
        version = text(a.get("versionString"), a.get("version"), item.get("versionString"))
        platform = text(a.get("platform"), item.get("platform"))
        ident = text(item.get("id"), a.get("id"))
        if ident and version == sys.argv[2] and (not platform or platform.upper() == sys.argv[3].upper()):
            print(ident)
            raise SystemExit(0)
    for item in items:
        ident = text(item.get("id"), attrs(item).get("id"))
        if ident:
            print(ident)
            raise SystemExit(0)
    raise SystemExit("no version id")

if query == "build":
    ident = ""
    version = ""
    if isinstance(obj, dict):
        ident = text(
            obj.get("buildId"),
            obj.get("build_id"),
            obj.get("buildVersion"),
        )
        version = text(obj.get("buildVersion"), obj.get("buildNumber"))
        rel = obj.get("relationships") or {}
        if isinstance(rel, dict):
            build = rel.get("build") or {}
            if isinstance(build, dict):
                data = build.get("data") or {}
                if isinstance(data, dict):
                    ident = text(ident, data.get("id"))
        included = obj.get("included") or []
        if isinstance(included, list):
            for entry in included:
                if isinstance(entry, dict) and entry.get("type") == "builds":
                    ident = text(ident, entry.get("id"))
                    version = text(version, attrs(entry).get("version"), attrs(entry).get("buildNumber"))
        data = obj.get("data")
        if isinstance(data, dict):
            ident = text(ident, data.get("buildId"), (data.get("relationships") or {}).get("build", {}).get("data", {}).get("id"))
            inner = data.get("relationships") or {}
            if isinstance(inner, dict):
                bdata = ((inner.get("build") or {}).get("data") or {})
                if isinstance(bdata, dict):
                    ident = text(ident, bdata.get("id"))
            version = text(version, data.get("buildVersion"))
    if not ident:
        raise SystemExit("no build")
    print(f"{ident}\t{version}")
    raise SystemExit(0)

if query == "screenshot_summary":
    types = []
    file_count = 0
    for item in items:
        a = attrs(item)
        display = text(
            a.get("screenshotDisplayType"),
            a.get("displayType"),
            item.get("screenshotDisplayType"),
        )
        if display:
            types.append(display)
        shots = a.get("screenshots") or item.get("screenshots") or []
        if isinstance(shots, list):
            file_count += len(shots)
        elif isinstance(shots, dict) and isinstance(shots.get("data"), list):
            file_count += len(shots["data"])
        if text(a.get("fileName"), item.get("fileName")):
            file_count += 1
    if not types:
        file_count = max(file_count, len(items))
        print(f"NONE\t0\t{file_count}")
        raise SystemExit(0)
    unique = ",".join(sorted(set(types)))
    has_69 = 1 if "APP_IPHONE_69" in types else 0
    print(f"{unique}\t{has_69}\t{file_count}")
    raise SystemExit(0)

if query == "review":
    if isinstance(obj, dict) and obj.get("configured") is False:
        raise SystemExit("not configured")
    payload = obj.get("data", obj) if isinstance(obj, dict) else obj
    if isinstance(payload, list):
        payload = payload[0] if payload else {}
    a = attrs(payload) if isinstance(payload, dict) else {}
    email = text(a.get("contactEmail"), payload.get("contactEmail") if isinstance(payload, dict) else "")
    notes = text(a.get("notes"), payload.get("notes") if isinstance(payload, dict) else "")
    ident = text(payload.get("id") if isinstance(payload, dict) else "", a.get("id"))
    if not ident and not email and not notes:
        raise SystemExit("review details missing")
    print(f"{ident}\t{email}\t{notes}")
    raise SystemExit(0)

if query == "pricing":
    payload = obj.get("data", obj) if isinstance(obj, dict) else obj
    if isinstance(payload, list):
        payload = payload[0] if payload else {}
    if not isinstance(payload, dict) or not payload:
        raise SystemExit("pricing missing")
    ident = text(payload.get("id"), attrs(payload).get("id"))
    available = payload.get("availableInNewTerritories")
    nested = payload.get("attributes") if isinstance(payload.get("attributes"), dict) else {}
    if available is None:
        available = nested.get("availableInNewTerritories")
    price = text(
        nested.get("customerPrice"),
        payload.get("customerPrice"),
        nested.get("proceeds"),
    )
    print(f"{ident}\t{available}\t{price}")
    raise SystemExit(0)

raise SystemExit(f"unknown query {query}")
' "${query}" "${VERSION}" "${PLATFORM}"
}

workdir="$(mktemp -d "${TMPDIR:-/tmp}/asc-preflight.XXXXXX")"
cleanup() {
  rm -rf "${workdir}"
}
trap cleanup EXIT

run_asc() {
  local outfile="$1"
  shift
  local errfile="${outfile}.err"
  local status=0
  "$@" >"${outfile}" 2>"${errfile}" || status=$?
  return "${status}"
}

detail_from() {
  local file="$1"
  local err="${file}.err"
  python3 -c '
import sys
from pathlib import Path
parts = []
for path in sys.argv[1:]:
    text = Path(path).read_text(errors="replace").strip()
    if text:
        parts.append(text)
joined = " | ".join(parts).replace("\n", " ")
print(joined[:300])
' "${file}" "${err}"
}

echo "App Store preflight (read-only, will not submit)"
echo "app ${APP_ID}  version ${VERSION}  platform ${PLATFORM}"
echo

if ! command -v asc >/dev/null 2>&1; then
  record FAIL "asc CLI" "asc is not installed (see .github/workflows/ios-testflight.yml, rudrankriyam/setup-asc)"
else
  validate_file="${workdir}/validate.json"
  if run_asc "${validate_file}" asc validate --app "${APP_ID}" --version "${VERSION}" --platform "${PLATFORM}" --output json; then
    record PASS "asc validate" "asc validate --app ${APP_ID} --version ${VERSION} --platform ${PLATFORM}"
  else
    record FAIL "asc validate" "$(detail_from "${validate_file}")"
  fi

  versions_file="${workdir}/versions.json"
  version_id=""
  if run_asc "${versions_file}" asc versions list --app "${APP_ID}" --version "${VERSION}" --platform "${PLATFORM}" --output json; then
    if version_id="$(json_query version_id <"${versions_file}")"; then
      :
    else
      version_id=""
    fi
  fi

  if [ -z "${version_id}" ]; then
    record FAIL "build attached" "could not resolve App Store version ${VERSION} for app ${APP_ID}"
    record FAIL "screenshots present" "skipped; no version id"
    record FAIL "review details set" "skipped; no version id"
  else
    build_file="${workdir}/build.json"
    if run_asc "${build_file}" asc versions view --version-id "${version_id}" --include-build --output json; then
      if build_info="$(json_query build <"${build_file}")"; then
        build_id="${build_info%%$'\t'*}"
        build_version="${build_info#*$'\t'}"
        if [ -n "${build_version}" ]; then
          record PASS "build attached" "version ${version_id}; build ${build_id} (${build_version})"
        else
          record PASS "build attached" "version ${version_id}; build ${build_id}"
        fi
      else
        record FAIL "build attached" "version ${version_id} has no build"
      fi
    else
      record FAIL "build attached" "$(detail_from "${build_file}")"
    fi

    loc_file="${workdir}/localizations.json"
    loc_id=""
    if run_asc "${loc_file}" asc localizations list --version "${version_id}" --locale en-US --output json; then
      loc_id="$(python3 -c '
import json, sys
obj = json.load(sys.stdin)
items = obj.get("data", obj)
if isinstance(items, dict):
    items = [items]
for item in items or []:
    ident = item.get("id")
    if ident:
        print(ident)
        break
' <"${loc_file}" || true)"
    fi

    if [ -z "${loc_id}" ]; then
      record FAIL "screenshots present" "no en-US version localization on ${version_id}"
    else
      sets_file="${workdir}/screenshot-sets.json"
      shots_file="${workdir}/screenshots.json"
      has_69=0
      types="none"
      file_count=0
      if run_asc "${sets_file}" asc localizations screenshot-sets list --localization-id "${loc_id}" --output json; then
        if summary="$(json_query screenshot_summary <"${sets_file}")"; then
          types="${summary%%$'\t'*}"
          rest="${summary#*$'\t'}"
          has_69="${rest%%$'\t'*}"
        fi
      fi
      if run_asc "${shots_file}" asc screenshots list --version-localization "${loc_id}" --output json; then
        if shot_summary="$(json_query screenshot_summary <"${shots_file}")"; then
          file_count="${shot_summary##*$'\t'}"
        fi
      fi
      if [ "${has_69}" = "1" ] && [ "${file_count}" -gt 0 ] 2>/dev/null; then
        record PASS "screenshots present" "APP_IPHONE_69 present with ${file_count} screenshot(s) (${types})"
      else
        record FAIL "screenshots present" "need a non-empty 6.9-inch APP_IPHONE_69 set (types ${types}; files ${file_count})"
      fi
    fi

    review_file="${workdir}/review.json"
    if run_asc "${review_file}" asc review details-for-version --version-id "${version_id}" --output json; then
      if review_info="$(json_query review <"${review_file}")"; then
        review_email="$(printf '%s\n' "${review_info}" | awk -F '\t' '{print $2}')"
        review_notes="$(printf '%s\n' "${review_info}" | awk -F '\t' '{print $3}')"
        missing=()
        if [ -z "${review_email}" ]; then
          missing+=("contact email")
        fi
        if [ -z "${review_notes}" ]; then
          missing+=("notes")
        fi
        if [ "${#missing[@]}" -eq 0 ]; then
          record PASS "review details set" "contact email and notes present"
        else
          record FAIL "review details set" "missing $(IFS=', '; echo "${missing[*]}")"
        fi
      else
        record FAIL "review details set" "review details not configured for version ${version_id}"
      fi
    else
      record FAIL "review details set" "$(detail_from "${review_file}")"
    fi
  fi

  pricing_file="${workdir}/pricing.json"
  availability_file="${workdir}/availability.json"
  pricing_ok=0
  pricing_detail=""
  if run_asc "${pricing_file}" asc pricing schedule view --app "${APP_ID}" --output json; then
    if pricing_info="$(json_query pricing <"${pricing_file}")"; then
      pricing_ok=1
      pricing_id="${pricing_info%%$'\t'*}"
      pricing_detail="schedule ${pricing_id}"
    else
      pricing_detail="price schedule empty"
    fi
  else
    pricing_detail="$(detail_from "${pricing_file}")"
  fi
  if run_asc "${availability_file}" asc pricing availability view --app "${APP_ID}" --output json; then
    if json_query pricing <"${availability_file}" >/dev/null; then
      pricing_ok=1
      if [ -n "${pricing_detail}" ]; then
        pricing_detail="${pricing_detail}; availability present"
      else
        pricing_detail="availability present"
      fi
    fi
  fi
  if [ "${pricing_ok}" -eq 1 ]; then
    record PASS "pricing set" "${pricing_detail}"
  else
    record FAIL "pricing set" "${pricing_detail:-no schedule or availability}"
  fi
fi

echo "Pass/fail"
echo "---------"
for row in "${results[@]}"; do
  status="${row%%|*}"
  rest="${row#*|}"
  name="${rest%%|*}"
  detail="${rest#*|}"
  if [ -n "${detail}" ]; then
    printf '%-4s  %s — %s\n' "${status}" "${name}" "${detail}"
  else
    printf '%-4s  %s\n' "${status}" "${name}"
  fi
done
echo "---------"
echo "${pass_count} passed, ${fail_count} failed"
echo "Read-only: this script does not submit version ${VERSION}."

if [ "${fail_count}" -ne 0 ]; then
  exit 1
fi
