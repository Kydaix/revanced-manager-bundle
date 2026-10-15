#!/usr/bin/env bash
# Applique les modifications de ce dépôt sur un clone du ReVanced Manager officiel.
#
# Usage : scripts/prepare.sh <dossier du clone officiel>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM_DIR="${1:?Usage : prepare.sh <dossier du clone officiel>}"

# shellcheck source=../config.env
source "$ROOT/config.env"

cd "$UPSTREAM_DIR"

for patch in "$ROOT"/patches/*.patch; do
    name="$(basename "$patch")"

    if git apply --check "$patch" 2>/dev/null; then
        git apply "$patch"
        echo "OK : $name"
        continue
    fi

    # Le code a bougé autour des lignes modifiées : fusion 3-way à partir de la version
    # sur laquelle le patch a été écrit.
    echo "Application directe impossible pour $name, tentative 3-way depuis $BASE_TAG"
    git fetch --quiet --depth 1 origin "refs/tags/$BASE_TAG:refs/tags/$BASE_TAG"
    if ! git apply --3way "$patch"; then
        echo "::error::$name ne s'applique plus sur cette version. Conflits :" >&2
        git diff --name-only --diff-filter=U >&2 || true
        exit 1
    fi
    echo "OK (3-way) : $name"
done

# Identité de l'application.
gradle_file=app/build.gradle.kts
sed -i -E "s/applicationId = \"[^\"]+\"/applicationId = \"$APPLICATION_ID\"/" "$gradle_file"
grep -q "applicationId = \"$APPLICATION_ID\"" "$gradle_file" || {
    echo "::error::applicationId introuvable dans $gradle_file" >&2
    exit 1
}

find app/src/main/res -path '*/values*/strings.xml' -print0 |
    xargs -0 sed -i -E "s#(<string name=\"app_name\">)[^<]*(</string>)#\1$APP_NAME\2#"

echo "Application : $APP_NAME ($APPLICATION_ID)"
