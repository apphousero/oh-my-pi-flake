#!/usr/bin/env bash
# Rewrites version and asset hashes in package.nix from the upstream release's
# published SHA256SUMS.txt. Run from the repository root, or via `nix run .#update`.
set -euo pipefail

repo="can1357/oh-my-pi"
target="${OMP_PACKAGE_NIX:-package.nix}"

assets=(
  "x86_64-linux:omp-linux-x64"
  "aarch64-linux:omp-linux-arm64"
  "x86_64-darwin:omp-darwin-x64"
  "aarch64-darwin:omp-darwin-arm64"
)

if [ ! -f "$target" ]; then
  echo "update: $target not found; run from the repository root" >&2
  exit 1
fi

auth=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

version="${1:-}"
if [ -z "$version" ]; then
  version=$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$repo/releases/latest" | jq -r .tag_name)
fi
version="${version#v}"

if [ -z "$version" ] || [ "$version" = "null" ]; then
  echo "update: could not determine a release version" >&2
  exit 1
fi

current=$(sed -n 's/^  version = "\(.*\)";$/\1/p' "$target")
sums=$(curl -fsSL "https://github.com/$repo/releases/download/v$version/SHA256SUMS.txt")

pairs=""
for entry in "${assets[@]}"; do
  asset="${entry##*:}"
  hex=$(printf '%s\n' "$sums" | awk -v a="$asset" '$2 == a { print $1 }')
  if [ -z "$hex" ]; then
    echo "update: v$version publishes no asset named '$asset'" >&2
    echo "update: available assets:" >&2
    printf '%s\n' "$sums" | awk '{ print "  " $2 }' >&2
    exit 1
  fi
  sri="sha256-$(printf '%s' "$hex" | tr 'a-f' 'A-F' | basenc --base16 -d | basenc --base64 -w0)"
  pairs="$pairs$asset=$sri "
done

awk -v ver="$version" -v pairs="$pairs" '
  BEGIN {
    n = split(pairs, kv, " ")
    for (i = 1; i <= n; i++) {
      if (kv[i] == "") continue
      eq = index(kv[i], "=")
      hash[substr(kv[i], 1, eq - 1)] = substr(kv[i], eq + 1)
    }
  }
  /^  version = "/ { sub(/"[^"]*"/, "\"" ver "\""); print; next }
  /asset = "/ {
    match($0, /"[^"]*"/)
    asset = substr($0, RSTART + 1, RLENGTH - 2)
    print
    next
  }
  /hash = "/ && asset != "" {
    if (!(asset in hash)) { print "update: no hash for " asset > "/dev/stderr"; exit 1 }
    sub(/"[^"]*"/, "\"" hash[asset] "\"")
    asset = ""
  }
  { print }
' "$target" >"$target.tmp"

mv "$target.tmp" "$target"

if [ "$current" = "$version" ]; then
  echo "update: already at $version (hashes refreshed from SHA256SUMS.txt)"
else
  echo "update: $current -> $version"
fi
