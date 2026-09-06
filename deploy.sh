#!/usr/bin/env bash
# Build the Flutter web release and update the site-only `gh-pages` branch.
#
# Usage:
#   ./deploy.sh            build + update local gh-pages branch (then push yourself)
#   ./deploy.sh --push     also push gh-pages to origin
#
# The commit is built with git plumbing, so your current branch and working
# tree are left untouched. Run it from any branch EXCEPT gh-pages.
set -euo pipefail

BASE_HREF="/bowl-designer/"   # project-site sub-path; use "/" for a root domain
BRANCH="gh-pages"

cd "$(dirname "$0")"

current="$(git symbolic-ref --short HEAD 2>/dev/null || echo DETACHED)"
if [[ "$current" == "$BRANCH" ]]; then
  echo "You're on '$BRANCH'. Switch to your source branch first (e.g. git checkout master)." >&2
  exit 1
fi

# Gate the build on texture validation: every bundled wood image must decode and
# be a power-of-two square, else the 3D grain samples as garbage on the GPU
# (see test/wood_textures_test.dart). Fails fast before building.
echo "▶ Validating bundled wood textures…"
flutter test test/wood_textures_test.dart

echo "▶ Building web release (base href $BASE_HREF)…"
flutter build web --release --base-href "$BASE_HREF"

# Assemble the exact tree to publish (site files + .nojekyll) in a temp dir.
site="$(mktemp -d)"
idx="$(mktemp -u)"
trap 'rm -rf "$site" "$idx"' EXIT
cp -R build/web/. "$site"/
rm -f "$site/.last_build_id"
touch "$site/.nojekyll"          # tell GitHub Pages not to run Jekyll

# Write that tree into a fresh commit on gh-pages via a throwaway index.
GIT_INDEX_FILE="$idx" GIT_WORK_TREE="$site" git add -A
tree="$(GIT_INDEX_FILE="$idx" git write-tree)"
parent=()
if git rev-parse --verify --quiet "refs/heads/$BRANCH" >/dev/null; then
  parent=(-p "refs/heads/$BRANCH")
fi
commit="$(git commit-tree "$tree" "${parent[@]}" \
  -m "Deploy web build ($(date +%Y-%m-%d), base href $BASE_HREF)")"
git update-ref "refs/heads/$BRANCH" "$commit"

echo "✔ $BRANCH updated → $(git rev-parse --short "$BRANCH")"

if [[ "${1:-}" == "--push" ]]; then
  echo "▶ Pushing $BRANCH to origin…"
  git push origin "$BRANCH"
  echo "✔ Pushed. Live at https://alexfeinman.github.io${BASE_HREF}"
else
  echo "Next:  git push origin $BRANCH"
fi
