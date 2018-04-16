#!/bin/bash

GRAY='\033[0;90m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

function verbose() {
  printf "\n${GRAY}[  $(date +'%Y-%m-%d %H:%M:%S')  VERB  ]  $1${NC}"
}

function debug() {
  printf "\n${GRAY}[  $(date +'%Y-%m-%d %H:%M:%S')  DEBUG ]  $1${NC}"
}

function info() {
  printf "\n${GREEN}[  $(date +'%Y-%m-%d %H:%M:%S')  INFO  ]  $1${NC}"
}

function warn() {
  printf "\n${YELLOW}[  $(date +'%Y-%m-%d %H:%M:%S')  WARN  ]  $1${NC}"
}

function error() {
  printf "\n${RED}[  $(date +'%Y-%m-%d %H:%M:%S')  ERROR ]  $1${NC}"
}

# Usage: fatal "Message" [exitCode]
function fatal() {
  printf "\n${RED}[  $(date +'%Y-%m-%d %H:%M:%S')  FATAL ]  $1${NC}\n"
  exit ${2:-1}
}

function confirm() {
  warn "${1} (Y/n)"
  exec < /dev/tty
  read -n 1 CH

  if [ "${CH}" == "y" ] || [ "${CH}" == "Y" ]; then
    return 0
  else
    return 1
  fi
}
