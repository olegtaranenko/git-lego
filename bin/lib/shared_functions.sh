#!/usr/bin/env bash

function parse_opt() {
 echo "parse_opt"
}


function in_consistentwork () {
  declare -x gitDir
  git rev-parse --git-dir &> /dev/null
  ret=$?
  if [[ 0 -ne $ret ]]; then
    die
    exit 1
  fi

  unset $gitDir

  gitDir=`git rev-parse --git-dir`
  normalizedGitDir=${gitDir##*/}
  cwRoot=$(pwd)
  if [[ ${normalizedGitDir} == ".git" ]]; then
    cwRoot=$(git rev-parse --show-toplevel)
  else
    pushd "${gitDir%%/.git/*}"  > /dev/null
    cwRoot=$(git rev-parse --show-toplevel)
    popd  > /dev/null
  fi

  local url=$(get_repo_url "$cwRoot")
  local cwUrl=${url%%gitadmin@git.consistentwork.com:*}
  if [[ -nz ${cwUrl} ]]; then
    cw_echo ${cwUrl}
    die
  fi

  splash ${url}
  return $ret
}

function die() {
  cw_echo "You are not in one of ConsistentWork repositories. Look in "$(dirname $0)"/Readme.MD for more information"
  exit 1
}

function cw_echo() {
  echo $(basename $0)": "$1
}

function splash() {
  local url=$1
  url=${url##*:}
  local msg="umbrella repo: \"${url}\""
  currentUrl=$(get_repo_url ".")
  if [[ ${currentUrl} != ${url} ]]; then
    msg+="; current: \"${currentUrl##*:}\""
  fi
  cw_echo "${msg}"
}

function get_repo_url() {
  [[ $1 == "." ]] || pushd $1  > /dev/null
  local url=$(git remote get-url origin)
  [[ $1 == "." ]] || popd  > /dev/null
  echo ${url}
}
