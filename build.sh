#!/usr/bin/env bash
#
# Build a multi-arch (linux/amd64 + linux/arm64) image and, with PUSH=1, push
# it to the CHI registry.
#
#   ./build.sh                     build only, nothing leaves this machine
#   PUSH=1 ./build.sh              build and push $VERSION, $VERSION-g$SHA and latest
#   PRERELEASE=1 PUSH=1 ./build.sh push only $VERSION-g$SHA
#
# PRERELEASE exists so a build can be tested on a real deployment without claiming either
# of the two tags that mean “this is the release”. The -g$SHA tag names one commit and
# nothing else, so a test deployment that pins it is unambiguous, and neither the version
# tag nor latest moves until the release is actually cut.
#
# Requires a one-time `podman login chi-tools.uc.edu` before pushing.
#
# Environment overrides:
#   REGISTRY    registry host           (default chi-tools.uc.edu)
#   PLATFORMS   comma-separated targets (default linux/amd64,linux/arm64)
#   PUSH        set to 1 to push
#   PRERELEASE  set to 1 to push only the $VERSION-g$SHA tag
#   FORCE       set to 1 to allow pushing from a dirty working tree
#
set -euo pipefail
cd "$(dirname "$0")"

REGISTRY=${REGISTRY:-chi-tools.uc.edu}
PLATFORMS=${PLATFORMS:-linux/amd64,linux/arm64}

NAME=assets
VERSION=$(<VERSION)
REVISION=$(git rev-parse --short HEAD)
git diff --quiet HEAD -- . || REVISION="${REVISION}-dirty"

IMAGE="${REGISTRY}/${NAME}"

if ! command -v podman >/dev/null 2>&1; then
  echo "build.sh: podman is required for multi-arch builds" >&2
  exit 1
fi
ENGINE=podman

# A manifest list left over from a previous run is added to, not replaced, so
# stale per-arch entries would accumulate. Start clean.
$ENGINE manifest rm "${IMAGE}:${VERSION}" 2>/dev/null || true

# --platform with a comma list plus --manifest builds every leg and assembles
# the image index in one invocation.
$ENGINE build --pull=newer \
  --platform "$PLATFORMS" \
  --manifest "${IMAGE}:${VERSION}" \
  --build-arg VERSION="$VERSION" \
  --build-arg REVISION="$REVISION" \
  --build-arg CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  .

# Tagging a manifest list gives the same list another name, so all three tags
# stay multi-arch.
$ENGINE tag "${IMAGE}:${VERSION}" "${IMAGE}:${VERSION}-g${REVISION}" "${IMAGE}:latest"

echo
echo "built ${IMAGE}:${VERSION}"
echo "       ${IMAGE}:${VERSION}-g${REVISION}"
echo "       ${IMAGE}:latest"

if [[ ${PUSH:-0} != 1 ]]; then
  echo
  echo "not pushed (set PUSH=1 to push to ${REGISTRY})"
  exit 0
fi

if [[ "$REVISION" == *-dirty && ${FORCE:-0} != 1 ]]; then
  echo >&2
  echo "build.sh: refusing to push a build from a dirty working tree." >&2
  echo "          Commit first, or set FORCE=1 to override." >&2
  exit 1
fi

if [[ ${PRERELEASE:-0} == 1 ]]; then
  TAGS=("${VERSION}-g${REVISION}")
  echo "prerelease: pushing only ${IMAGE}:${VERSION}-g${REVISION}"
else
  TAGS=("${VERSION}" "${VERSION}-g${REVISION}" latest)
fi

# --all is required: without it only the index is pushed and the per-arch
# manifests it references can be missing from the registry.
for TAG in "${TAGS[@]}"; do
  echo "pushing ${IMAGE}:${TAG}"
  $ENGINE manifest push --all "${IMAGE}:${VERSION}" "docker://${IMAGE}:${TAG}"
done

# `set -e` already aborts on a failed push, so this is not a failure check. It is here to
# catch a push that succeeded at the wrong thing — PRERELEASE not taking effect and latest
# quietly moving, say. That is why every remote tag is listed, not just the ones this run
# pushed. Advisory only: a registry hiccup after a successful push must not fail the script.
#
# Note this proves a tag exists, not that its per-arch manifests are all present. Pushing
# without --all produces a tag that lists fine here and fails on pull.
echo
echo "verifying against ${REGISTRY}…"
if REMOTE=$($ENGINE search --list-tags "${IMAGE}" 2>/dev/null) && [[ -n "$REMOTE" ]]; then
  for TAG in "${TAGS[@]}"; do
    if grep -qE "[[:space:]]${TAG}\$" <<<"$REMOTE"; then
      echo "  ok      ${TAG}"
    else
      echo "  MISSING ${TAG}"
    fi
  done
  echo "  all tags now in the registry:"
  sed 1d <<<"$REMOTE" | awk '{print "    " $2}'
else
  echo "  could not reach ${REGISTRY} to verify — the push itself succeeded"
fi
