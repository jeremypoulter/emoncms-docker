#!/bin/sh
# Install every component listed in components.lock at its pinned commit and
# write a manifest of what is in the image.
set -eu
lock=${1:?usage: install-components.sh <components.lock> <manifest.json>}
manifest=${2:?missing manifest path}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
while read -r name path repo ref commit; do
    case "$name" in ''|'#'*) continue ;; esac
    printf '%s' "$commit" | grep -Eq '^[0-9a-f]{40}$' || {
        echo "$name: '$commit' is not a 40-character commit" >&2
        exit 1
    }
    mkdir -p "$path"
    git -C "$path" init -q
    git -C "$path" remote add origin "$repo"
    git -C "$path" fetch -q --depth 1 origin "$commit"
    git -C "$path" checkout -q --detach FETCH_HEAD
    [ "$(git -C "$path" rev-parse HEAD)" = "$commit" ]
    # Version comes from the component's own metadata.
    version=
    for f in module.json version.json; do
        if [ -f "$path/$f" ]; then
            version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$path/$f" | head -1)
            break
        fi
    done
    [ -n "$version" ] || version=$ref
    printf '{"name":"%s","repository":"%s","ref":"%s","commit":"%s","version":"%s"}\n' \
        "$name" "$repo" "$ref" "$commit" "$version" >> "$tmp"
done < "$lock"
{ printf '['; paste -sd, "$tmp"; printf ']\n'; } > "$manifest"
