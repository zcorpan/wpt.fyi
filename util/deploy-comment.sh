#!/bin/bash

# Helper script for posting a GitHub comment pointing to the deployed environment,
# from Travis CI. Also see deploy.sh

set -e
set -o pipefail

DEPLOYED_URL="$1"

REPO_DIR="$(dirname "$0")/.."
source "${REPO_DIR}/util/logging.sh"

if [[ -z ${GITHUB_TOKEN} ]]; then fatal "GitHub Token is required"; fi
if [[ -z "${DEPLOYED_URL}" ]];
then fatal "Deployed URL is required";
else info "Deployed URL: ${DEPLOYED_URL}";
fi
if [[ -z "${TRAVIS_REPO_SLUG}" ]];
then fatal "Travis Repo slug (user/repo) is required";
else info "Travis Repo slug: ${TRAVIS_REPO_SLUG}";
fi
if [[ -z "${TRAVIS_PULL_REQUEST}" ]];
then fatal "Travis pull request is required";
else info "Travis pull request: ${TRAVIS_PULL_REQUEST}";
fi

info "Checking whether ${TRAVIS_REPO_SLUG} #${TRAVIS_PULL_REQUEST} mentions the deployed URL on GitHub..."
# Only make a comment mentioning the deploy if no other comment has posted the URL yet.

TEMP_CURL_FILE=$(mktemp)
curl -s \
     -H "Authorization: token ${GITHUB_TOKEN}" \
     -X GET \
     https://api.github.com/repos/${TRAVIS_REPO_SLUG}/issues/${TRAVIS_PULL_REQUEST}/comments \
     | tee ${TEMP_CURL_FILE}
if [ "${CURL_EXIT_CODE:=${PIPESTATUS[0]}}" != "0" ]; then fatal "Failed to fetch comments" ${CURL_EXIT_CODE}; fi

echo a
STAGING_LINK=$(cat "${TEMP_CURL_FILE}" | grep "${DEPLOYED_URL}")
echo b
if [[ -z "${STAGING_LINK}" ]];
then
    echo c
    info "Commenting URL to GitHub..."
    curl -H "Authorization: token ${GITHUB_TOKEN}" \
          -X POST \
          -d "{\"body\": \"Staging instance deployed by Travis CI!\n Running at ${DEPLOYED_URL}\"}" \
          -vv \
          https://api.github.com/repos/${TRAVIS_REPO_SLUG}/issues/${TRAVIS_PULL_REQUEST}/comments
else
    echo d
    info "Found existing comment mentioning link:\n${STAGING_LINK}"
fi

echo e
sync
