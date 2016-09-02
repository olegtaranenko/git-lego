#!/usr/bin/env bash

function parse_opt() {
 echo "parse_opt"
}

#function _submodule_git_commit() {
#  name=$1
#  path=$2
#  toplevel=$3
#  sha1=$4
#  echo "$name $toplevel/$path $sha1"
#
#  cat /tmp/_submodule_git_commit.params | args
#  cd $toplevel/$path
##  git add . -A
##  git commit -am "******** first commit via submodules"
##  echo ${args[*]}
##  git commit ${args[*]}
#  return 0
#}
#
#export -f _submodule_git_commit

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
  if [[ -nz ${cwUrl} ]]; then
    cw_echo ${cwUrl}
    die
  fi

  #globals is an array defined in the caller of this method
  globals[0]=${umbrellaRepoDir}
  globals[1]=${cwTmpSubmodules}
  globals[2]=${gitDir}

  rm ${cwTmpSubmodules} &>/dev/null
  splash ${url}
  pushd ${umbrellaRepoDir} &>/dev/null
  git submodule  foreach --recursive  |  tail  -r | sed "s/[^']*//" | tr -d "'" >>  ${cwTmpSubmodules}

  popd ${umbrellaRepoDir} &>/dev/null
  return 0
}

function die() {
  local msg="$1"
  [ -z "${msg}" ] && "You are not in one of ConsistentWork repositories. Look in "$(dirname $0)"/Readme.MD for more information"
  cw_echo "${msg}"
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

function is_branch_exists() {
  [[ -z $1 ]] && (die "Wrong arguments for is_branch_exists method")
  local branchName=$1
  git rev-parse --no-revs origin/"$branchName" &>/dev/null
  local ret=$?
  if [[ ${ret} == 0 ]]; then
    ret=1
  else
    ret=0
  fi
  echo ${ret}
  return ${ret}
}
