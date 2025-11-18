#!/bin/bash -e 

AWS_REGION="us-gov-west-1"
REGISTRY_URL="<account_id>.dkr.ecr.us-gov-west-1.amazonaws.com"

SERVICE="${SERVICE:-}"
TAG="${TAG:-}"
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
##: "${EXPECTED_SHA:?EXPECTED_SHA (sha256:...) is required}"

case "$SERVICE" in
  formio-enterprise)   PULL_REPO="formio/formio-enterprise";        PUSH_REPO="/vendor/formio-enterprise" ;;
  formio-pdf)          PULL_REPO="formio/pdf-server";  PUSH_REPO="/vendor/formio-pdf" ;;
  spell-checker)       PULL_REPO="webspellchecker/wproofreader";    PUSH_REPO="/vendor/spellcheck" ;;
  cke-core)            PULL_REPO="docker.cke-cs.com/cs";            PUSH_REPO="/vendor/cke-core" ;;
  cke-docx)            PULL_REPO="docker.cke-cs.com/docx-converter";PUSH_REPO="/vendor/cke-docx" ;;
  etlworks-app)        PULL_REPO="etlworks/etlworks-app";           PUSH_REPO="/vendor/etlworks-app" ;;
  metabase)            PULL_REPO="metabase/metabase-enterprise";    PUSH_REPO="/vendor/metabase" ;;
  *) echo "Invalid service: $SERVICE"; exit 2 ;;
esac

pullandtag() {
  if [[ "$SERVICE" == "cke-core" || "$SERVICE" == "cke-docx" ]]; then
    docker pull --platform=linux/amd64 "${PULL_REPO}@${EXPECTED_SHA}"
    docker tag "${PULL_REPO}@${EXPECTED_SHA}" "${REGISTRY_URL}${PUSH_REPO}:${TAG}"
  else
    docker pull "${PULL_REPO}:${TAG}"
    docker tag "${PULL_REPO}:${TAG}" "${REGISTRY_URL}${PUSH_REPO}:${TAG}"
  fi
}

validate_digest() {
  local src_ref tgt_image actual_sha
  if [[ "$SERVICE" == "cke-core" || "$SERVICE" == "cke-docx" ]]; then
    src_ref="${PULL_REPO}@${EXPECTED_SHA}"
  else
    src_ref="${PULL_REPO}:${TAG}"
  fi
  tgt_image="${REGISTRY_URL}${PUSH_REPO}:${TAG}"

  actual_sha="$(docker inspect --format='{{range .RepoDigests}}{{println .}}{{end}}' "${src_ref}" \
    | grep -E "^${PULL_REPO}@sha256:" | head -n1 | awk -F@ '{print $2}')"

  [[ -n "$actual_sha" ]] || { echo "ERROR: Could not determine digest for ${src_ref}"; exit 1; }

  if [[ -n "${EXPECTED_SHA:-}" ]]; then
    echo "Expected digest: ${EXPECTED_SHA}"
    echo "Actual digest:   ${actual_sha}"
    [[ "$EXPECTED_SHA" == "$actual_sha" ]] || { echo "❌ Digest verification FAILED"; exit 1; }
  else
    echo "No EXPECTED_SHA set; resolved: ${actual_sha}"
  fi

  echo "✅ Verified — pushing ${tgt_image}"
  docker push "${tgt_image}"
}

resolve_amd64_digest() {
  docker manifest inspect "${PULL_REPO}:${TAG}" \
    | jq -r '.manifests[] | select(.platform.os=="linux" and .platform.architecture=="amd64") | .digest' \
    | sed -n '1p'
}

aws-dest ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY_URL}"

if [[ "$SERVICE" == "cke-core" || "$SERVICE" == "cke-docx" ]]; then
  : "${CKE_PASS:?Set CKE_PASS for docker.cke-cs.com}"
  echo "$CKE_PASS" | docker login docker.cke-cs.com -u cs --password-stdin

  if [[ -z "${EXPECTED_SHA:-}" ]]; then
    EXPECTED_SHA="$(resolve_amd64_digest)"
    if [[ -z "${EXPECTED_SHA}" ]]; then
      echo "ERROR: Could not resolve amd64 digest for ${PULL_REPO}:${TAG}"; exit 1
    fi
    echo "Resolved amd64 digest for ${PULL_REPO}:${TAG}: ${EXPECTED_SHA}"
    echo "Set EXPECTED_SHA to this value and re-run for a verified mirror."
    exit 0
  fi
fi

pullandtag
validate_digest