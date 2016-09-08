#!/usr/bin/env bash


  # After call to 'umbrella_bootstrap' this array contains following predefined values.
  #
  ## "${globals[$G_ROOT_DIR]}" [cwRoot]           - path to umbrella repository
  ## "${globals[$G_MODULES_FN]}" [cwTmpSubmodules]  - temporary file name, which listed all current repositories with additional information
  ## "${globals[$G_MODULE_GIT_DIR]}" [gitDir]           - current repository (or sub repository, from the
  #
globals=()
  #
  ## Umbrella repo path
  #
G_ROOT_DIR=0
  #
  ## Reference to temp file which keeps all submodules' path in reversed order
  ##  It is useful to apply regular actions against all modules, like bulk commit,push,etc
  #
G_MODULES_FN=1
  #
  ## reference to git directory for current submodule in umbrella coordinates.
  #
G_MODULE_GIT_DIR=2
  #
  ## Human-readable name of umbrella path
  #
G_ROOT_NAME=3
  #
  ## Temporary folder owned by script invocation
G_SCRIPT_TMP_DIRECTORY=4



#
## CONSTANTS for module status (see function module_porcelain_status()
#
MS_BRANCH_INFO=0
MS_DETACHED=1
MS_COMMITABLE=2
MS_UNTRACKED=3
MS_MODIFIED=4
MS_DELETED=5
MS_ADDED=6
MS_RENAMED=7
MS_COPIED=8
MS_UNMERGED=9


#
## CONSTANTS for module file system
## Array is filled up in function umbrella_bootstrap () and serves for path resolution
#
MFS_MODULE_NAME=0
MFS_RELATIVE_PATH=1
MFS_GIT_DIR=2
MFS_FULL_PATH=3

function umbrella_bootstrap () {
  local gitDir
  local umbrellaRepoDir
  local tmpDir=$(mktemp -q -d -t "$(basename "$0")" 2>/dev/null || mktemp -q -d)
  globals[$G_SCRIPT_TMP_DIRECTORY]=${tmpDir}

  tmpModules=${tmpDir}/modules
  echo ${tmpModules} >&2
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

#  rm ${cwTmpSubmodules} &>/dev/null
  pushd ${umbrellaRepoDir} &>/dev/null

  umbrellaOriginUrl=$(git remote get-url origin)
  umbrellaRepoName=${umbrellaOriginUrl##*:}
  umbrellaRepoName=${umbrellaRepoName##*/}

#  git submodule foreach --recursive  |  sed "s/[^']*//" | tr -d "'" >>  ${tmpModules}

  #globals is an array defined in the caller of this method
  globals[$G_ROOT_DIR]=${umbrellaRepoDir}
  globals[$G_MODULES_FN]=${tmpModules}
  globals[$G_MODULE_GIT_DIR]=${gitDir}
  globals[$G_ROOT_NAME]=${umbrellaRepoName}

  module_startup_investigate
  cat $tmpModules >&2

  popd &>/dev/null
  splash ${url}

  return 0
}


function module_startup_investigate() {
  while read -a module; do
#    subModule="${module[0]}"                 # MFS_MODULE_NAME=0
    localPath="${module[1]}"                  # MFS_RELATIVE_PATH=1

    pushd ${localPath} &> /dev/null
    module+=($(get_repo_git_dir))             # MFS_GIT_DIR=2
    tmpModules="${globals[$G_MODULES_FN]}"
    module+=($(pwd))                          # MFS_FULL_PATH=3
    echo "${module[@]}">>${tmpModules}
    module_startup_investigate
    popd &> /dev/null
  done < <(git config -f .gitmodules --get-regexp "submodule.*.path" | sed -E "s/submodule\.(.*)\.path/\1/")
}

function umbrella_finalize() {
  rm -rf ${globals[$G_SCRIPT_TMP_DIRECTORY]}
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

typeset MODULE_STATUS=()
#
##  Get status for current module
#
#     Filling up $MODULE_STATUS array with parsed information about current module state.
#     Information in the array will be valid till next call of the method.
#     Directory of module should be set outside this function.
#
## Parameters
#     none
#
## Globals affected
#     $MODULE_STATUS array
#
function module_porcelain_status () {
#  set -x

#  local pwd
#  if [[ -n $1 && $1 != "." && $1 != "/" && $1 != ".." ]]; then
#    pwd=$1
#    pushd $pwd  &> /dev/null
#  elif [[ $1 == "/" ]]; then
#    pwd=${globals[0]}
#    pushd $pwd  &> /dev/null
#  else
#    pwd=$(pwd)
#  fi
  unset MODULE_STATUS

  while read -a output; do
    case ${output[0]} in
      \#\#)
        if [[ -n ${output[1]} ]]; then
          if [[ ${output[1]} == "HEAD" ]]; then
            MODULE_STATUS[$MS_DETACHED]=1
            possibleBranch=$(possible_branch_from_parent_config)
            if [[ -n $possibleBranch ]]; then
              MODULE_STATUS[$MS_BRANCH_INFO]="detached (${possibleBranch}?)"
            fi
          fi
          [[ -z ${MODULE_STATUS[$MS_BRANCH_INFO]} ]] && MODULE_STATUS[$MS_BRANCH_INFO]="${output[@]:1}"
        fi
      ;;
      *)
        cmd=${output:0:2}
        case ${cmd} in
          \?\?)
            MODULE_STATUS[$MS_UNTRACKED]=1
          ;;
          *)
            [[ ${cmd:0:1} == "M" || ${cmd:1:1} == "M" ]] && MODULE_STATUS[$MS_MODIFIED]=1; MODULE_STATUS[$MS_COMMITABLE]=1
            [[ ${cmd:0:1} == "A" || ${cmd:1:1} == "A" ]] && MODULE_STATUS[$MS_ADDED]=1; MODULE_STATUS[$MS_COMMITABLE]=1
            [[ ${cmd:0:1} == "D" || ${cmd:1:1} == "D" ]] && MODULE_STATUS[$MS_DELETED]=1; MODULE_STATUS[$MS_COMMITABLE]=1
            [[ ${cmd:0:1} == "R" || ${cmd:1:1} == "R" ]] && MODULE_STATUS[$MS_RENAMED]=1; MODULE_STATUS[$MS_COMMITABLE]=1
            [[ ${cmd:0:1} == "C" || ${cmd:1:1} == "C" ]] && MODULE_STATUS[$MS_COPIED]=1; MODULE_STATUS[$MS_COMMITABLE]=1
            [[ ${cmd:0:1} == "U" || ${cmd:1:1} == "U" ]] && MODULE_STATUS[$MS_UNMERGED]=1; MODULE_STATUS[$MS_COMMITABLE]=1
          ;;
        esac
      ;;
    esac
  done < <(git status -u --porcelain -b)

#  [[ -n $1 && $1 != "." ]] && popd  &> /dev/null
#  set +x
}

function module_up() {
  cd $(git rev-parse --show-toplevel)"/.."
  cd $(git rev-parse --show-toplevel)
}

function possible_branch_from_parent_config() {
  local ret repoName
  repoName=$(get_repo_name_from_path)
  if [[ $repoName != "/" ]]; then
    pushd . &> /dev/null

    module_up
    ret=$(git config -f .gitmodules --get "submodule.$repoName.branch")
    popd &> /dev/null
  else
    ret=/       ## TODO check, maybe better return empty string?
  fi
  echo ${ret}
}
