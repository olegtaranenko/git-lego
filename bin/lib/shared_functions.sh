#!/usr/bin/env bash

function consistentwork_bootstrap () {
  local gitDir
  local umbrellaRepoDir
  local -r cwTmpSubmodules="/tmp/_cw_submodules"
  git rev-parse --git-dir &> /dev/null
  ret=$?
  if [[ 0 -ne $ret ]]; then
    die
    exit 1
  fi

  gitDir=$(git rev-parse --git-dir)
  normalizedGitDir=${gitDir##*/}
  if [[ ${normalizedGitDir} == ".git" ]]; then
    umbrellaRepoDir=$(git rev-parse --show-toplevel)
  else
    pushd "${gitDir%%/.git/*}"  > /dev/null
    umbrellaRepoDir=$(git rev-parse --show-toplevel)
    popd  > /dev/null
  fi

  local url=$(get_repo_url "$umbrellaRepoDir")
  local cwUrl=${url%%gitadmin@git.consistentwork.com:*}
  if [[ -n ${cwUrl} ]]; then
    cw_echo ${cwUrl}
    die
  fi

  rm ${cwTmpSubmodules} &>/dev/null
  pushd ${umbrellaRepoDir} &>/dev/null
  umbrellaOriginUrl=$(git remote get-url origin)
  umbrellaRepoName=${umbrellaOriginUrl##*:}
  umbrellaRepoName=${umbrellaRepoName##*/}
  git submodule  foreach --recursive  |  tail  -r | sed "s/[^']*//" | tr -d "'" >>  ${cwTmpSubmodules}


  #globals is an array defined in the caller of this method
  globals[0]=${umbrellaRepoDir}
  globals[1]=${cwTmpSubmodules}
  globals[2]=${gitDir}
  globals[3]=${umbrellaRepoName}
  popd &>/dev/null
  splash ${url}

  return 0
}

function die() {
  local msg="$1"
  [ -z "${msg}" ] && "You are not in one of ConsistentWork repositories. Look in "$(dirname $0)"/Readme.MD for more information"
  cw_echo "${msg}"
  exit 1
}

function panic() {
  local msg="$1"
  [ -z "${msg}" ] && "Unexpected error. Please check the code or call to support"
  cw_echo "${msg}"
  exit 2
}

typeset cwVerboseContinue=0
function cw_cr() {
  printf "\n"

}
function cw_echo() {
  echo "${0##*/}: $1"
  if [[ -n "$2" ]]; then
    shift
    while [ -n "$1" ]; do
      cw_verbose "$1\n"
      shift
    done
    cw_verbose_stop
  fi
}

function cw_verbose () {
  (( $verbose )) && printf "verbose: $1" >&2
}

function cw_verbose_stop () {
  if (( $verbose )) && (( $cwVerboseContinue )); then
    cwVerboseContinue=0
    printf "\n" >&2
  fi
}

function splash() {
  (( $skipSplash )) && return
  local url=$1
  url=${url##*:}
  url=${url##*/}
  local msg="umbrella repo: "${url}
  local currentGitDir=$(get_repo_git_dir)
  currentRepoName=${currentGitDir##*/modules/}
  [[ -n ${currentRepoName} && ${url} != ${currentRepoName} ]] && msg+=", current module '"${currentRepoName}"'"
  cw_echo "${msg}"
}

function get_repo_url() {
  [[ -n $1 && $1 != "." ]] && pushd $1  > /dev/null
  local url=$(git remote get-url origin)
  [[ -n $1 && $1 != "." ]] && popd  > /dev/null
  echo ${url}
}

function get_repo_name_from_path() {
  [[ -n $1 && $1 != "." ]] && pushd $1  > /dev/null
  local gitDir=$(get_repo_git_dir)
  [[ -n $1 && $1 != "." ]] && popd  > /dev/null
  local name="${gitDir##*/modules/}"
  [[ $name == ".git" ]] && echo "/" || echo "$name"
}

function get_repo_git_dir() {
  [[ -n $1 && $1 != "." ]] && pushd $1  > /dev/null
  local url=$(git rev-parse --git-dir)
  [[ -n $1 && $1 != "." ]] && popd  > /dev/null
  echo ${url}
}

function is_branch_exists() {
  [[ -z $1 ]] && (panic "'branch' argument for is_branch_exists() should be given")
  local branchName=$1
  local where=$2
  local checkedSites=("", "origin")
  if [[ -n $where ]]; then
    # TODO
    die "'where' parameter for is_branch_exists() not implemented yet"
  fi

  for prefix in "${checkedSites[@]}"; do
    (( ${#prefix} )) && prefix+="/"
    git rev-parse --no-revs "${prefix}${branchName}" &>/dev/null
    local ret=$?
    if (( ! $ret )); then
      ret=1
    else
      ret=0
    fi
    if (( $ret )); then
     break
    fi
  done

  echo ${ret}
  return ${ret}
}
