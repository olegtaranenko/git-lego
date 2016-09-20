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

#  echo ${tmpModules} >&2

  _m_not_git_repository; (( $? )) && exit 1

  gitDir=$(git rev-parse --git-dir)
  normalizedGitDir=${gitDir##*/}
  if [[ ${normalizedGitDir} == ".git" ]]; then
    umbrellaRepoDir=$(git rev-parse --show-toplevel)
  else
    pushd "${gitDir%%/.git/*}"  > /dev/null
    umbrellaRepoDir=$(git rev-parse --show-toplevel)
    popd  > /dev/null
  fi

#  rm ${cwTmpSubmodules} &>/dev/null
  pushd ${umbrellaRepoDir} &>/dev/null

  local remoteOrigin=$(git remote show)
  local umbrellaOriginUrl umbrellaRepoName
  if [[ -n $remoteOrigin ]]; then
    local url=$(get_repo_url "$umbrellaRepoDir")
#    local cwUrl=${url%%gitadmin@git.consistentwork.com:*}
#    if [[ -n ${cwUrl} ]]; then
#      cw_echo ${cwUrl}
#      die
#    fi
    umbrellaOriginUrl=$(git remote get-url origin)
    umbrellaRepoName=${umbrellaOriginUrl##*:}
    umbrellaRepoName=${umbrellaRepoName##*/}

  else
    umbrellaOriginUrl=$(pwd)
    umbrellaRepoName=${umbrellaOriginUrl##*/}
  fi

  globals[$G_AFFECTED_MODULES]=${tmpDir}/affected
  globals[$G_MODULES_FN]=${tmpDir}/modules

#  git submodule foreach --recursive  |  sed "s/[^']*//" | tr -d "'" >>  ${tmpModules}

  #globals is an array defined in the caller of this method
  globals[$G_ROOT_DIR]=${umbrellaRepoDir}
  globals[$G_MODULE_GIT_DIR]=${gitDir}
  globals[$G_ROOT_NAME]=${umbrellaRepoName}

  module_startup_investigate "${umbrellaRepoName}" "/" ".git" "${umbrellaRepoDir}" "/"
#  cat ${globals[$G_MODULES_FN]} >&2

  popd &>/dev/null
  splash ${umbrellaRepoName}

  return 0
}


function module_startup_investigate() {
  local tmpModules=${globals[$G_MODULES_FN]}
  echo "$@">>${tmpModules}
  # map emulation for quick access of the
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
  local msg="umbrella repo: "${url}
  local currentGitDir=$(get_repo_git_dir)
  local currentRepoName=${currentGitDir##*/modules/}
  [[ -n ${currentRepoName} && ${url} != ${currentRepoName} && $currentGitDir != ".git" ]] && msg+=", current module '"${currentRepoName}"'"
  cw_echo "${msg}"
}

function get_repo_url() {
  [[ -n $1 && $1 != "." ]] && pushd $1  &> /dev/null
  local url=$(git remote get-url origin &> /dev/null)
  [[ -n $1 && $1 != "." ]] && popd  &> /dev/null
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
    local found=0
    local moduleName=${module[$MFS_MODULE_NAME]}
    local fullPath=${module[MFS_FULL_PATH]}
    if [ "$levelPath" == "$fullPath" ]; then
      found=1
      if (( ${#afterDash[@]} )); then
        found=0
        for dash in ${afterDash[@]}; do
          # exact comparison, not matching
          if [ "${moduleName}" == "${dash}" ]; then
            found=1
            break
          fi
        done
      fi
    fi

    if (( ${found} )); then
      affected=1
      echo ${module[@]} >> ${globals[$G_AFFECTED_MODULES]}
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
  local default="$2"

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

  [[ -z $originPath ]] && originPath="${default}"

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


  while [[ -n $1 ]]; do
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


construct_section_name() {
  local modulePath="$1"
  local extension="$2"
  local dir="${globals[$G_SCRIPT_TMP_DIRECTORY]}"
  local fn once=0

  if [[ ${#modulePath} == 0 || ${modulePath:0:1} != "/" ]]; then
    fn+="/"
  fi
  (( ${#modulePath} )) && fn+=${modulePath}

  fn=$(echo ${fn} | tr "/" "_")
  echo "$dir/${fn}.${extension}"
}

function export_gitmodules_section {
  echo ${FUNCNAME}": $@" >&2
  local modulePath="$1"
  local moduleName="$2"
  local revision="$3"
  local dumpFileName=$(construct_section_name "$1" "$3")
#  echo "${dumpFileName}"
#  pwd
  while  read -a module; do
    echo ${module[@]} >> ${dumpFileName}
  done < <(git config --file .gitmodules --get-regexp "submodule.${moduleName}.*")
#  cat "${dumpFileName}"
}

function import_gitmodules_section {
  echo ${FUNCNAME}": $@" >&2
  local modulePath="$1"
  local moduleName="$2"
  local revision="$3"
  local dumpFileName=$(construct_section_name "$1" "$3")
#  echo "${dumpFileName}"
#  pwd
  while  read -a setting; do
    git conifg --file .gitmodules ${setting[@]}
  done < <(cat "${dumpFileName}")
}


function prepare_checkout_level() {
  echo ${FUNCNAME}": $@" >&2
#  [[ -z ${levelPath} ]] && panic "$FUNCNAME()... parameter 'path' is required"
  local levelRevision="$1"
  local modulePath="$2"
  local moduleName="$3"
  local levelPath="$4"
  local toBeDeleted=$5
  local parentCheckBranch="$6"
  local parentCheckCommit="$7"
  local parentRevision="${parentCheckBranch}"
  if [[ -z "${parentRevision}" ]]; then
    parentRevision="${parentCheckCommit}"
  fi

  local -a modulesBefore
  local -a modulesAfter
  local -a removedModules

  local ret=0 checkRevision
  local childRet # child modules return code

  pushd "${levelPath}" &> /dev/null

  if (( $toBeDeleted )); then

    module_porcelain_status ${0##*/}

    if [[ 0 == ${force} &&  (1 == ${MODULE_STATUS[$MS_COMMITABLE]} || 1 == ${MODULE_STATUS[$MS_UNTRACKED]} || 1 == ${MODULE_STATUS[MS_PUSHABLE]}) ]]; then
      dieMsg+="Module '$moduleName' has not committed or not pushed changes, but intended to be deleted as it does not exists in revision '$revision'"
      ret=1
    fi

  else
    ### Use case when in new checkout revision the submodule not exists, but in current branch it is change
    ### It should be vetoed, but this veto can be disclosed only on the next call for getting if sub-module is
    ### commitable.
    while read -a module; do
      local after="${module[0]}"
      modulesAfter+=($after)
      local branchAfter=$(git config --blob ${levelRevision}:.gitmodules --get "submodule.${after}.branch" )
      local commitAfter=$(git config --blob ${levelRevision}:.gitmodules --get "submodule.${after}.commit" )
      local revisionAfter=${branchAfter}
      if [[ -z $revisionAfter ]]; then
        revisionAfter=${commitAfter}
      fi
      revisionsAfter+=(${revisionAfter})
    done < <(git config --blob ${levelRevision}:.gitmodules --get-regexp "submodule.*.path" | sed -E "s/submodule\.(.*)\.path/\1/" )

    local found=0
    while read -a module; do
      local b="${module[0]}"
      modulesBefore+=("$b")
      for a in ${modulesAfter[@]}; do
        if [[ $a == $b ]]; then
          found=1
          break
        fi
      done
      if (( ! $found )); then
        removedModules+=("${b}")
      fi
    done < <(git config -f .gitmodules --get-regexp "submodule.*.path" | sed -E "s/submodule\.(.*)\.path/\1/")

    drop_to_affected "${levelPath}"

    found=0
    while read -a module; do
      local after="${module[0]}"
      found=0
      for b in ${modulesBefore[@]}; do
        if [[ $after == $b ]]; then
          found=1
          break
        fi
      done
      if (( ! $found )); then
#        drop_to_affected "${levelPath}/${module[1]}"
        local localPath="${module[1]}"
        local childModulePath="${modulePath}"
        if [[ ${modulePath:(-1)} != "/" ]]; then
          local childModulePath+="/"
        fi
        childModulePath+="$after"
        ## dummy git dir
        echo "${after}" "${localPath}" "^" "${levelPath}/${localPath}" "$childModulePath" >> ${globals[$G_AFFECTED_MODULES]}
        affected=1
      fi
    done < <(git config --blob ${levelRevision}:.gitmodules --get-regexp "submodule.*.path" 2> /dev/null | sed -E "s/submodule\.(.*)\.path/\1/" )


    if [ -f .gitmodules ]; then
      while read -a module; do
        childRet=0
        subModule="${module[0]}"
        localPath="${module[1]}"
        local path="${levelPath}"/"${localPath}"

  #      checkoutd "${path}" &> /dev/null
        local childModulePath="${modulePath}"
        if [[ ${modulePath:(-1)} != "/" ]]; then
          local childModulePath+="/"
        fi
        childModulePath+="$subModule"

        local childToBeDeleted=0
        for b in ${removedModules[@]}; do
          if [[ $subModule == $b ]]; then
            childToBeDeleted=1
            break
          fi
        done

        if (( ! childToBeDeleted )); then
          local checkBranch=$(git config --blob "${levelRevision}":.gitmodules --get submodule."${subModule}".branch) 2> /dev/null
          local checkCommit=$(git config --blob "${levelRevision}":.gitmodules --get submodule."${subModule}".commit) 2> /dev/null
          checkRevision="${checkBranch}"
          if [[ -z $checkRevision ]]; then
            checkRevision="${checkCommit}"
          fi
        else
          checkRevision="^"
          # dump .gitmodules section in the separate temp file, (merge preparation)
#          export_gitmodules_section "${path}" "${subModule}" "${checkRevision}"
        fi

        prepare_checkout_level "${checkRevision}" "${childModulePath}" "${subModule}" "${path}" "${childToBeDeleted}" "${checkBranch}" "${checkCommit}"
        childRet=$?

        (( $childRet > $ret )) && ret=${childRet}
        popd  &> /dev/null

      done < <(git config -f .gitmodules --get-regexp "submodule.*.path" | sed -E "s/submodule\.(.*)\.path/\1/")
    fi
  fi

  popd &> /dev/null
  return ${ret}
} ## of prepare_checkout_level

##
## Checks branching state for current repository
## Let name the branch is synched if entry submodule.<subrepo>.branch in .gitmodules is matched
## to the branch of the sub-repository, (what can be checked via 'cd subrepo; git branch',
## It they are mismatched, 3 options are possible.
## 1. Sub-repo can be detached. In this case we are looking for value in the outer repo and doing git checkout branch
## 2. Sub-repo is pinned to another branch then it is given in .gitmodules. To sync this we just changing v
##    value in .gitmodules file of outer repo
## 3. Sub-repo is detached, no value in .gitmodules. We are unable to re-syncronize, notifying user about and exitiing.
## Parameters:
##      1. path [required] - path getting started checking. It can be called recursively to drill down to the leaves repos.
##      2. doSync [optional, by default 0] - perform synchronization (1) or not
## Returns
##
function check_branch_sync() {
  local levelPath="$1"
  doSync=${2:-0}
  [[ -z ${levelPath} ]] && panic "check_branch_sync()... parameter 'path' is required"
  local repoBranch
  local ret=0   # return code, 0 - the repo is syncronized
  local childRet # child return code
  cd "${levelPath}"

  while read -a repo; do
    childRet=0
    subRepoName="${repo[0]}"
    checkBranch=$(git config --file .gitmodules --get submodule."${subRepoName}".branch)
    checkPath="${repo[1]}"
    subRepoPath="${levelPath}"/"${checkPath}"

    #    echo "${subRepoName}" "${checkBranch}" "${checkPath}"

    pushd "${subRepoPath}" &> /dev/null
    #    pwd

    repoBranch=$(git rev-parse --abbrev-ref HEAD)
    local detached=0
    [[ "${repoBranch}" == "HEAD" ]] && detached=1

    #    echo "${repoBranch}"
    if [[ ${repoBranch} != ${checkBranch} ]]; then

      ret=1
      (( ! $doSync )) && cw_echo "Module ${subRepoName} is not synchronized"
      #      echo "$repoBranch != $checkBranch"

      #
      if [[ -n "${repoBranch}" && ${detached} == 0  ]]; then
        cd "${levelPath}"
        if (( $doSync )); then
          cw_echo "About to change reference in .gitmodules for submodule $subRepoName to branch $repoBranch"
          git config --file .gitmodules submodule."${subRepoName}".branch "${repoBranch}"
          ret=$?
        fi
      elif [[ -n "${checkBranch}" && ${detached} == 1 ]]; then
        cd "${subRepoPath}"
        if (( $doSync )); then
          cw_echo "About to checkout submodule $subRepoName to branch $checkBranch"
          git checkout ${checkBranch}
          ret=$?
        fi
      else
        cw_echo "Warning: submodule ${subRepoName} can't be syncronized"
        ret=2
      fi
    else
      (( $doView )) && cw_echo "Module '$subRepoName' at '$checkBranch' branch"
    fi

    if [[ -e .gitmodules ]]; then
      check_branch_sync "${subRepoPath}" ${doSync}
      childRet=$?
    fi
    (( $childRet )) && ret=1


    popd  &> /dev/null

    if (( $doSync )); then
      git diff --exit-code --quiet -- .gitmodules
      needToCommit=$?
      #echo "needToCommit=${needToCommit}"
      if (( $qeedToCommit )); then
        if (( $doAutoCommit )); then
          git add .gitmodules
          git commit -m "$subRepoName submodule configuration is changed"
        else
          needMessageToPush=1
        fi
      fi
    fi
  done < <(git config -f .gitmodules --get-regexp "submodule.*.path" | sed -E "s/submodule\.(.*)\.path/\1/")

  return "${ret}"
} ## of check_branch_sync

