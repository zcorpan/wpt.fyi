#!/bin/bash

# Helper script for using a standardized version flag when deploying.

set -e

REPO_DIR="$(dirname "$0")/.."
source "${REPO_DIR}/util/logging.sh"
source "${REPO_DIR}/util/path.sh"
WPTD_PATH=${WPTD_PATH:-$(absdir ${REPO_DIR})}

usage() {
  USAGE="Usage: deploy.sh [-p] [-q] [-b] [-r] [-i] [-h]
    -p Production deploy
    -q Quiet / no user prompts
    -b Branch name - defaults to current Git branch
    -r Repo slug (e.g. web-platform-tests/wpt.fyi), for making a Github comment
    -i Issue (PR) number, for making a Github comment
    -g Github token, for making a Github comment
    -h Show (this) help information"
  echo "${USAGE}"
}

PRODUCTION='false'
QUIET='false'

while getopts ':b:phqr:i:g:' flag; do
  case "${flag}" in
    b) BRANCH_NAME="${OPTARG}" ;;
    p) PRODUCTION='true' ;;
    q) QUIET='true' ;;
    r) REPO_SLUG="${OPTARG}" ;;
    i) PULL_REQUEST="${OPTARG}" ;;
    g) GITHUB_TOKEN="${OPTARG}" ;;
    h|*) usage && exit 0;;
  esac
done

# Ensure dependencies are installed.
info "Installing dependencies..."
cd ${WPTD_PATH}; make go_deps;

# Create a name for this version
BRANCH_NAME=${BRANCH_NAME:-"$(git rev-parse --abbrev-ref HEAD)"}
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
if [[ "${REPO_SLUG}" != "" && "${PULL_REQUEST}" != "" && "${GITHUB_TOKEN}" != "" ]];
then
    info "Checking whether ${REPO_SLUG} #${PULL_REQUEST} mentions the deployed URL on GitHub..."
    DEPLOYED_URL=$(gcloud app versions describe ${VERSION} -s default | grep -Po 'versionUrl:\K.*$')
    if [[ "${DEPLOYED_URL}" != "" ]];
    then
        # Only make a comment mentioning the deploy if no other comment has posted the URL yet.
        STAGING_LINK=$(curl -s -X GET https://api.github.com/repos/${REPO_SLUG}/issues/${PULL_REQUEST}/comments | grep ${DEPLOYED_URL})
        if [[ ${STAGING_LINK} == "" ]];
        then
            info "Commenting URL to GitHub..."
            curl -H "Authorization: token ${GITHUB_TOKEN}" \
                 -X POST \
                 -d "{\"body\": \"Staging instance deployed by Travis CI!\n Running at ${DEPLOYED_URL}\"}" \
                 https://api.github.com/repos/${REPO_SLUG}/issues/${PULL_REQUEST}/comments
        else
            info "Found existing comment mentioning link:\n${STAGING_LINK}"
        fi
    fi
fi

 exit 0
