#!/usr/bin/env bash

trim_repo_value() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

normalize_repo_scoped_slug() {
  local trimmed

  trimmed="$(trim_repo_value "$1")"
  printf '%s' "$trimmed" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9-]+/-/g; s/-+/-/g; s/^-+//; s/-+$//'
}

build_canonical_worker_name() {
  local owner_slug repo_slug base preferred shortened_base hash trimmed_owner trimmed_repo

  owner_slug="$(normalize_repo_scoped_slug "$1")"
  repo_slug="$(normalize_repo_scoped_slug "$2")"

  if [[ -n "$owner_slug" && -n "$repo_slug" ]]; then
    base="${owner_slug}-${repo_slug}"
  elif [[ -n "$owner_slug" ]]; then
    base="$owner_slug"
  elif [[ -n "$repo_slug" ]]; then
    base="$repo_slug"
  else
    base="githubclaw"
  fi

  preferred="${base}-claw-worker"
  if [[ ${#preferred} -le 63 ]]; then
    printf '%s' "$preferred"
    return 0
  fi

  shortened_base="$(printf '%s' "${base:0:42}" | sed -E 's/-+$//')"
  if [[ -z "$shortened_base" ]]; then
    shortened_base="githubclaw"
  fi

  trimmed_owner="$(trim_repo_value "$1")"
  trimmed_repo="$(trim_repo_value "$2")"
  hash="$(
    printf '%s\n%s' "$trimmed_owner" "$trimmed_repo" \
      | shasum -a 256 \
      | awk '{print substr($1, 1, 8)}'
  )"

  printf '%s-claw-worker-%s' "$shortened_base" "$hash"
}

build_legacy_worker_name() {
  local repo_slug

  repo_slug="$(normalize_repo_scoped_slug "$1")"
  if [[ -n "$repo_slug" ]]; then
    printf '%s-claw' "$repo_slug"
  fi
}

derive_worker_name_from_workers_dev_url() {
  local trimmed_url

  trimmed_url="$(trim_repo_value "$1")"
  if [[ "$trimmed_url" =~ ^https://([a-z0-9-]+)\.[^.]+\.workers\.dev(/.*)?$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

print_worker_name_candidates() {
  local canonical legacy stored_worker_name stored_worker_url_name stored_githubclaw_worker_url_name
  local seen candidate

  canonical="$(build_canonical_worker_name "$1" "$2")"
  legacy="$(build_legacy_worker_name "$2")"
  stored_worker_name="$(trim_repo_value "${3:-}")"
  stored_worker_url_name="$(derive_worker_name_from_workers_dev_url "${4:-}")"
  stored_githubclaw_worker_url_name="$(derive_worker_name_from_workers_dev_url "${5:-}")"
  seen=$'\n'

  for candidate in \
    "$stored_worker_name" \
    "$stored_worker_url_name" \
    "$stored_githubclaw_worker_url_name" \
    "$canonical" \
    "$legacy"
  do
    if [[ -z "$candidate" ]]; then
      continue
    fi

    if [[ "$seen" == *$'\n'"${candidate}"$'\n'* ]]; then
      continue
    fi

    printf '%s\n' "$candidate"
    seen="${seen}${candidate}"$'\n'
  done
}

resolve_existing_worker_name() {
  local api_token account_id owner repo stored_worker_name stored_worker_url stored_githubclaw_worker_url
  local response success errors candidate matched

  api_token="$1"
  account_id="$2"
  owner="$3"
  repo="$4"
  stored_worker_name="${5:-}"
  stored_worker_url="${6:-}"
  stored_githubclaw_worker_url="${7:-}"

  if ! response="$(
    curl --fail --show-error --silent \
      "https://api.cloudflare.com/client/v4/accounts/${account_id}/workers/scripts" \
      -H "Authorization: Bearer ${api_token}" \
      -H "Content-Type: application/json"
  )"; then
    return 2
  fi

  success="$(printf '%s' "$response" | jq -r '.success // false')"
  if [[ "$success" != "true" ]]; then
    errors="$(printf '%s' "$response" | jq -c '.errors // []')"
    echo "::error::無法列出 Cloudflare Workers: ${errors}" >&2
    return 2
  fi

  while IFS= read -r candidate; do
    matched="$(
      printf '%s' "$response" \
        | jq -r --arg workerName "$candidate" '.result[]? | select(.id == $workerName) | .id' \
        | head -n 1
    )"
    if [[ -n "$matched" ]]; then
      printf '%s' "$matched"
      return 0
    fi
  done < <(
    print_worker_name_candidates \
      "$owner" \
      "$repo" \
      "$stored_worker_name" \
      "$stored_worker_url" \
      "$stored_githubclaw_worker_url"
  )

  return 1
}
