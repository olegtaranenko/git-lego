#!/usr/bin/env bash


  # After call to 'umbrella_bootstrap' this array contains following predefined values.
  #
  ## "${globals[$G_ROOT_DIR]}" [cwRoot]           - path to umbrella repository
  ## "${globals[$G_MODULES_FN]}" [cwTmpSubmodules]  - temporary file name, which listed all current repositories with additional information
  ## "${globals[$G_MODULE_GIT_DIR]}" [gitDir]           - current repository (or sub repository, from the
  #
globals=()

  ## Global arrays for quick access of
g_module_name=()
g_relative_paths=()
g_git_dirs=()
g_full_paths=()
g_module_paths=()

  ################################## CONSTANTS FOR globals array ##########################################
  #
  ## Umbrella repo path
  #
G_ROOT_DIR=0
  #
  ## reference to git directory for current submodule in umbrella coordinates.
  #
G_MODULE_GIT_DIR=1
  #
  ## Human-readable name of umbrella path
  #
G_ROOT_NAME=2
  #
  ## Temporary folder owned by script invocation
G_SCRIPT_TMP_DIRECTORY=3
  #
  ## Reference to temp file which keeps all submodules' path in reversed order
  ##  It is useful to apply regular actions against all modules, like bulk commit,push,etc
  #
G_MODULES_FN=4
  #
  ## Reference to temp file which keeps all submodules' path in reversed order
  ##  It is useful to apply regular actions against all modules, like bulk commit,push,etc
  #
G_AFFECTED_MODULES=5



#################### CONSTANTS for MODULE STATUS (see function module_porcelain_status() ####################
#
MS_BRANCH_INFO=0   # String
MS_DETACHED=1      # 1/0
MS_COMMITABLE=2    # 1/0
MS_UNTRACKED=3     # ?
MS_MODIFIED=4      # M
MS_DELETED=5       # D
MS_ADDED=6         # A
MS_RENAMED=7       # R
MS_COPIED=8        # C
MS_UNMERGED=9      # U
MS_PUSHABLE=10     # 1/0
MS_PULLABLE=11     # 1/0
MS_SUBMODULES=12   # S



########################### CONSTANTS FOR MODULE FILE SYSTEM  ###############################################
## Array is filled up in function umbrella_bootstrap () and serves for path resolution
#
MFS_MODULE_NAME=0
MFS_RELATIVE_PATH=1
MFS_GIT_DIR=2
MFS_FULL_PATH=3
MFS_MODULE_PATH=4

function umbrella_bootstrap () {
  local gitDir
  local umbrellaRepoDir
  local tmpDir=$(mktemp -q -d -t "$(basename "$0")" 2>/dev/null || mktemp -q -d)
  globals[$G_SCRIPT_TMP_DIRECTORY]=${tmpDir}

  tmpModules=${tmpDir}/modules
#  echo ${tmpModules} >&2
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
  globals[$G_AFFECTED_MODULES]=${tmpDir}/affected
  globals[$G_MODULE_GIT_DIR]=${gitDir}
  globals[$G_ROOT_NAME]=${umbrellaRepoName}

  module_startup_investigate "${umbrellaRepoName}" "/" ".git" "${umbrellaRepoDir}" "/"
#  cat $tmpModules >&2

  popd &>/dev/null
  splash ${url}

  return 0
}


function module_startup_investigate() {
  echo "$@">>${tmpModules}
  # map emulation for quick
  g_module_name+=($1)
  g_relative_paths+=($2)
  g_git_dirs+=($3)
  g_full_paths+=($4)
  g_module_paths+=($5)

  while read -a module; do
    subModule="${module[MFS_MODULE_NAME]}"
    localPath="${module[MFS_RELATIVE_PATH]}"

    pushd ${localPath} &> /dev/null
    module+=($(get_repo_git_dir))             # MFS_GIT_DIR=2
    tmpModules="${globals[$G_MODULES_FN]}"
    module+=($(pwd))                          # MFS_FULL_PATH=3

    if [[ $5 == "/" ]]; then                  # MFS_MODULE_PATH = 4
      module+=("/$subModule")
    else
      module+=("$5/$subModule")
    fi

    module_startup_investigate ${module[@]}
    popd &> /dev/null
  done < <(git config -f .gitmodules --get-regexp "submodule.*.path" | sed -E "s/submodule\.(.*)\.path/\1/")
}

function umbrella_finalize() {
  rm -rf ${globals[$G_SCRIPT_TMP_DIRECTORY]}
  _m_finalize
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
  echo "panic: ${msg}"
  exit 2
}

typeset cwVerboseContinue=0

function cw_cr() {
  printf "\n" >&2

}

function cw_echo() {
  echo "${0##*/}: $1"
  if [[ -n "$2" ]]; then
    shift
    cw_verbose_start
    while [ -n "$1" ]; do
      cw_verbose "$1\n"
      shift
    done
    cw_verbose_stop
  fi
}

function cw_verbose_start () {
  cwVerboseContinue=1
}


function cw_verbose () {
  if (( $verbose )); then
    printf "verbose: $1" >&2
    (( ! $cwVerboseContinue )) && printf "\n" >&2
  fi
}

function cw_verbose_stop () {
  if (( $verbose )); then
    if (( $cwVerboseContinue )); then
      printf "\n" >&2
    fi
    cwVerboseContinue=0
  fi
}

function splash() {
  (( $skipSplash )) && return
  local url=$1
  url=${url##*:}
  url=${url##*/}
  local msg="umbrella repo: "${url}
  local currentGitDir=$(get_repo_git_dir)
  local currentRepoName=${currentGitDir##*/modules/}
  [[ -n ${currentRepoName} && ${url} != ${currentRepoName} && $currentGitDir != ".git" ]] && msg+=", current module '"${currentRepoName}"'"
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

function get_module_path_up() {
  local ret=1

  if [[ $1 != "/" ]]; then
    local path=${1%/*}

    (( ! ${#path} )) && path="/"
    ret=0

  fi

  (( ! $ret )) && echo "${path}"
  return ${ret}
}


function level_verbose_about_to {

  local path=$4
  local info="about to ${0##*/} module '${1}'"
  # global
  verboseMsg=([1]="path: $path")
  verboseMsg+=("url: "$(get_repo_url))

  if (( $verbose )); then
    cw_cr
  fi

  local fineIssues infoIssues
  verboseMsg[0]=${info}
#set +x
  cw_echo "${verboseMsg[@]}"

}


#
## Checks affected modules, which can be set after double dash
## ie. status / -- libs will check only libs module
#
# Parameters
#     $1 Module's full path to be tested on existence in afterDash array
#
# Returns
#     0 - module is found and listed in after dash parameters, or after-dash parameters are not set
#     1 - module is found but not listed in after dash parameters (out-filtered)
#     2 - N/A module is not found or wrong argument
#
# Globals using
#     $afterDash - array contains module list after double dash
#
function drop_to_affected() {
  local ret=0
  local levelPath=$1

  [[ -z $levelPath ]] && return 2;

  while read -a module; do
    local moduleName=${module[$MFS_MODULE_NAME]}
    local found=0
    local fullPath=${module[MFS_FULL_PATH]}
    if [ "$levelPath" == "$fullPath" ]; then
      found=1
      if (( ! ${#afterDash[@]} )); then
        for dash in ${afterDash[@]}; do
          # exact comparison, not matching
          if [ "${moduleName}" == "${dash}" ]; then
            found=1
            break
          fi
        done
      fi
      if (( ! ${found} )); then
        ret=1
      else
        affected=1
        echo ${module[@]} >> ${globals[$G_AFFECTED_MODULES]}
      fi
      break
    fi
  done < <(cat ${globals[$G_MODULES_FN]})

  return ${ret}
}


function get_module_path_down() {
  local path
  local origin="$1"
  local reminder="$2"
  if [[ ${origin:(-1)} == "/" ]]; then
    path="$origin$reminder"
  else
    path="$origin/$reminder"
  fi

  local ret=1

  for mp in ${g_module_paths[@]}; do
    if [[ ${mp} == ${path} ]]; then
      ret=0
      break
    fi
  done

  (( ! $ret )) && echo "${path}"
  return ${ret}
}


function resolve_module_path() {
  cantResolve="Can't resolve module path '$1'"
  local originPath reminder="$1"

  if [[ -n ${reminder} ]]; then
    if [[ -n ${reminder%%/*} && -n ${reminder%%../*} && $reminder != ".." && -n ${reminder%%./*} && $reminder != "." ]]; then
      reminder="./$reminder"
    fi

    if [[ -z ${reminder%%/*} ]]; then
      originPath="/"
      reminder=${reminder:1}
    elif [[ -z ${reminder%%../*} || $reminder == ".." ]]; then
      reminder=${reminder:3}
      originPath=$(pmd)
      originPath=$(get_module_path_up ${originPath})
      (( $? )) && die "${cantResolve}"
    elif [[ -z ${reminder%%./*} || $reminder == "." ]]; then
      reminder=${reminder:2}
      originPath=$(pmd)
    fi

    if (( ${#reminder} )); then
      IFS="/" read -a parts <<< $reminder
      for part in $parts; do
        case $part in
          \.\.\.)
            die "${cantResolve}"
          ;;
          \.\.)
            originPath=$(get_module_path_up ${originPath})
            (( $? )) && die "${cantResolve}"
          ;;
          \.)
            ## nothing
          ;;
          *)
            originPath=$(get_module_path_down ${originPath} ${part})
            (( $? )) && die "${cantResolve}"
          ;;
        esac
      done
    fi
  fi

  [[ -z $originPath ]] && originPath="/"

  echo "${originPath}"
}

function module_info () {
  local modulePath="$1"
  shift
  local index=0
  local ret=1
  local results=()
  for mp in ${g_module_paths[@]}; do
    if [[ ${mp} = ${modulePath} ]]; then
      ret=0
      break
    fi
    index=$(( index + 1 ))
  done


  if (( ! $ret )); then
    ret=1
    while [[ -n $1 ]]; do
      ret=0
      case $1 in
        index)
          results+=($index)
          ;;
        name)
          results+=(${g_module_name[$index]})
          ;;
        relative|local)
          results+=(${g_relative_paths[$index]})
          ;;
        full|path)
          results+=(${g_full_paths[$index]})
          ;;
        gitdir)
          results+=(${g_git_dirs[$index]})
          ;;
        *)
          ret=2
          break
      esac
      shift
    done
  fi
  (( ${#results[@]} )) && echo ${results[@]}
  return ${ret}
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
#     $1 - mode, which indicated the caller script, ie. "status"/"commit"/...
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

  local interactionRemote=0
  [[ $1 == "push" || $1 == "pull" ]] && interactionRemote=1

  unset MODULE_STATUS
#  set -x
  while read line; do
    local output=(${line})
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
        # TODO will not working in locale differs form en
        # TODO git rev-list --count can help!!
        if (( $interactionRemote )); then
#          local remoteRef="origin/"
          local ahead=$(echo $line | grep -Eo "ahead [[:digit:]]" | grep -Eo "[[:digit:]]")
          (( ! $? )) && (( $ahead )) && MODULE_STATUS[$MS_PUSHABLE]=1
        fi
        ;;
      *)
        local cmd=${output:0:2}
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
#  set +x

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
