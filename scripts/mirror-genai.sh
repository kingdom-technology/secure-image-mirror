#!/bin/bash -e

# Regions/registries
SRC_REGION="${SRC_REGION:-us-west-2}"
DEST_REGION="${DEST_REGION:-us-gov-west-1}"

SRC_ACCOUNT_ID="${SRC_ACCOUNT_ID:-111111111111}"
DEST_ACCOUNT_ID="${DEST_ACCOUNT_ID:-222222222222}"

SRC_REGISTRY="${SRC_ACCOUNT_ID}.dkr.ecr.${SRC_REGION}.amazonaws.com"
DEST_REGISTRY="${DEST_ACCOUNT_ID}.dkr.ecr.${DEST_REGION}.amazonaws.com"

SERVICE="${SERVICE:-}"
TAG="${TAG:-}"
DEST_TAG="${DEST_TAG:-}"
EXPECTED_SHA="${EXPECTED_SHA:-}"

while getopts ":s:t:d:" flag; do
  case "${flag}" in
    s) SERVICE="${OPTARG}";;
    t) TAG="${OPTARG}";;
    d) EXPECTED_SHA="${OPTARG}";;
  esac
done

: "${SERVICE:?SERVICE is required}"
: "${TAG:?TAG is required}"

case "$SERVICE" in
  genai-api)                   PULL_REPO="docshunter-genai-ai-api";     PUSH_REPO="docshunter-genai-ai-api" ;;
  pdf-nlm-ingestor)            PULL_REPO="pdf-nlm-ingestor";            PUSH_REPO="pdf-nlm-ingestor" ;;
  text-embeddings-inference)   PULL_REPO="docshunter-genai-embeddings";   PUSH_REPO="text-embeddings-inference" ;;
  *) echo "Invalid service: $SERVICE"; exit 2 ;;
esac

SRC_IMAGE_TAG="${SRC_REGISTRY}/${PULL_REPO}:${TAG}"
DEST_IMAGE_TAG="${DEST_REGISTRY}/${PUSH_REPO}:${DEST_TAG}"

login_src() {
  : "${SRC_AWS_ACCESS_KEY:?missing SRC_AWS_ACCESS_KEY}"
  : "${SRC_AWS_ACCESS_SECRET_KEY:?missing SRC_AWS_ACCESS_SECRET_KEY}"
  export AWS_ACCESS_KEY_ID="$SRC_AWS_ACCESS_KEY"
  export AWS_SECRET_ACCESS_KEY="$SRC_AWS_ACCESS_SECRET_KEY"
  export AWS_SESSION_TOKEN="${SRC_AWS_SESSION_TOKEN:-}"
  aws-src ecr get-login-password --region "$SRC_REGION" \
    | docker login --username AWS --password-stdin "$SRC_REGISTRY"
}

login_dest() {
  : "${DEST_AWS_ACCESS_KEY:?missing DEST_AWS_ACCESS_KEY}"
  : "${DEST_AWS_ACCESS_SECRET_KEY:?missing DEST_AWS_ACCESS_SECRET_KEY}"
  export AWS_ACCESS_KEY_ID="$DEST_AWS_ACCESS_KEY"
  export AWS_SECRET_ACCESS_KEY="$DEST_AWS_ACCESS_SECRET_KEY"
  export AWS_SESSION_TOKEN="${DEST_AWS_SESSION_TOKEN:-}"
  aws-dest ecr get-login-password --region "$DEST_REGION" \
    | docker login --username AWS --password-stdin "$DEST_REGISTRY"
}

pullandtag() {
  docker pull "${SRC_IMAGE_TAG}"
  docker tag "${SRC_IMAGE_TAG}" "${DEST_IMAGE_TAG}"
}

validate_digest() {
  local actual_sha
  actual_sha="$(docker inspect --format='{{index .RepoDigests 0}}' "${SRC_IMAGE_TAG}" | awk -F@ '{print $2}')"
  [[ -n "$actual_sha" ]] || { echo "ERROR: Could not determine digest for ${SRC_IMAGE_TAG}"; exit 1; }

  if [[ -n "${EXPECTED_SHA:-}" ]]; then
    echo "Expected digest: ${EXPECTED_SHA}"
    echo "Actual digest:   ${actual_sha}"
    [[ "$EXPECTED_SHA" == "$actual_sha" ]] || { echo "❌ Digest verification FAILED"; exit 1; }
  else
    echo "No EXPECTED_SHA set; resolved: ${actual_sha}"
  fi

  echo "✅ Verified — pushing ${DEST_IMAGE_TAG}"
  docker push "${DEST_IMAGE_TAG}"
}

resolve_amd64_digest() {
  docker manifest inspect "${SRC_REGISTRY}/${PULL_REPO}:${TAG}" \
    | jq -r '.manifests[] | select(.platform.os=="linux" and .platform.architecture=="amd64") | .digest' \
    | sed -n '1p'
}

# ---- Main ----
login_src
login_dest


pullandtag
# If you want verification + push in one place, uncomment:
# validate_digest

docker push "${DEST_IMAGE_TAG}"
