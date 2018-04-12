#!/bin/bash

# Helper script for using a standardized version flag when deploying.

set -e

REPO_DIR="$(dirname "$0")/.."
source "${REPO_DIR}/util/logging.sh"
source "${REPO_DIR}/util/path.sh"
WPTD_PATH=${WPTD_PATH:-$(absdir ${REPO_DIR})}

usage() {
  info "Usage: deploy.sh [-p] [-h] [-q]";
}

PRODUCTION='false'
QUIET='false'

while getopts ':phq' flag; do
  case "${flag}" in
    p) PRODUCTION='true' ;;
    q) QUIET='true' ;;
    h|*) usage && exit 0;;
  esac
done

# Ensure dependencies are installed.
info "Installing dependencies..."
cd ${WPTD_PATH}; make go_deps;

# Create a name for this version
BRANCH_NAME=${TRAVIS_BRANCH:-"$(git rev-parse --abbrev-ref HEAD)"}
USER="$(git remote -v get-url origin | sed -E 's#(https?:\/\/|git@)github.com(\/|:)##' | sed 's#/.*$##')-"
if [[ "${USER}" == "web-platform-tests-" ]]; then USER=""; fi

VERSION="${USER}${BRANCH_NAME}"
PROMOTE="--no-promote"

if [[ ${PRODUCTION} == 'true' ]]
then
  info "Producing production configuration..."
  if [[ "${USER}" != "web-platform-tests" ]]
  then
    if [[ "${QUIET}" != "true" ]]
    then
      confirm "Are you sure you want to be deploying a non-web-platform-tests repo (${USER})?"
      if [ "${?}" != "0" ]; then exit "${?}"; fi
    fi
  fi
  # Use SHA for prod-pushes.
  VERSION="$(git rev-parse --short HEAD)"
  PROMOTE="--promote"
fi

if [[ "${QUIET}" == "true" ]]
then
    QUIET_FLAG="-q"
else
    QUIET_FLAG=""
fi
COMMAND="gcloud app deploy ${PROMOTE} ${QUIET_FLAG} --version=${VERSION} ${WPTD_PATH}/webapp"

info "Deploy command:\n${COMMAND}"
if [[ "${QUIET}" != "true" ]]
then
    confirm "Execute?"
    if [ "${?}" != "0" ]; then exit "${?}"; fi
fi

info "Executing..."
${COMMAND}

# Comment on the PR if running from Travis.
if [[ "${TRAVIS_REPO_SLUG}" != "" ]];
then
    info "Checking whether ${TRAVIS_REPO_SLUG} #${TRAVIS_PULL_REQUEST} mentions the deployed URL on GitHub..."
    DEPLOYED_URL=$(gcloud app versions describe ${VERSION} -s default | grep -Po 'versionUrl:\K.*$')
    if [[ "${DEPLOYED_URL}" != "" ]];
    then
        # Only make a comment mentioning the deploy if no other comment has posted the URL yet.
        STAGING_LINK=$(curl -s -X GET https://api.github.com/repos/${TRAVIS_REPO_SLUG}/issues/${TRAVIS_PULL_REQUEST}/comments | grep ${DEPLOYED_URL})
        if [[ ${STAGING_LINK} == "" ]];
        then
            info "Commenting URL to GitHub..."
            curl -H "Authorization: token ${GITHUB_TOKEN}" \
                 -X POST \
                 -d "{\"body\": \"Staging instance deployed by Travis CI!\n Running at ${DEPLOYED_URL}\"}" \
                 https://api.github.com/repos/${TRAVIS_REPO_SLUG}/issues/${TRAVIS_PULL_REQUEST}/comments
        else
            info "Found existing comment mentioning link:\n${STAGING_LINK}"
        fi
    fi
fi

 exit 0
