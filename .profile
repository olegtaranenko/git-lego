#!/usr/bin/env bash

if [ -n $CWORK_HOME ]; then
  # path where consistentwork projects are cloned
  export CWORK_HOME=~/consistentwork
fi
export PATH="~/.consistentwork/bin:$CWORK_HOME/bin:$PATH"



if [ -f /opt/local/etc/profile.d/.git-completion.bash ]; then
  source /opt/local/etc/profile.d/.git-completion.bash
fi

# preference to locally built git
# see https://gist.github.com/digitaljhelms/2931522 or https://github.com/git/git/blob/master/INSTALL how to build
# option make prefix=~ is being used
#
## WARNING: no use self-compiled git, because git subrepo is broken in this case
#
if [ -f ~/bin/nogit ]; then
  if [ "$(git --version)" != "$(~/bin/git --version)" ]; then
    export PATH="~/bin:$PATH"
  fi
fi

_mcd_die() {
  echo $1 >&2
  set +x
}


mcd() {
  local module scope
  local scope
#set -x

  while [[ -n $1 ]]; do
    (( $stopOptions )) && [[ -z ${1%%-*}  ]] && return 1
    case $1 in
      -h|-\?|--help)
        _mcd_help
        return 0
        ;;
      -v|--verbose)
        verbose=$((verbose + 1)) # Each -v argument adds 1 to verbosity.
        ;;

      *)
        if [[ -z ${scope} ]]; then
          scope="$1"
        elif [[ -z $module  ]]; then
          module="$1"
        else
          _mcd_die "error in parameters [$1]"
          return 1
        fi
        ;;
    esac
    shift
  done

  git rev-parse --git-dir &> /dev/null
  if (( $? )); then
    echo "Not a git repository" >&2
    return 1
  fi

  [[ -z ${scope} ]] && scope="/"

  local pathResolution=$(_mcd_path_resolution "${scope}")
  echo $pathResolution >&2
set +x
  return 0
}

function _mcd_path_resolution() {
  cantResolve="Can't resolve module path '$1'"
  local originPath reminder="$1"

  if [[ -n ${reminder} ]]; then
    if [[ -n ${reminder%%/*} && -n ${reminder%%../*} && $reminder != ".." && -n ${reminder%%./*} && $reminder != "." ]]; then
      reminder="./$reminder"
    fi

    if [[ -z ${reminder%%/*} ]]; then
      _mcd_root 1
      reminder=${reminder:1}
    elif [[ -z ${reminder%%../*} || $reminder == ".." ]]; then
      reminder=${reminder:3}
      _mcd_pwd 1
      _mcd_up 1
      (( $? )) && die "${cantResolve}"
    elif [[ -z ${reminder%%./*} || $reminder == "." ]]; then
      reminder=${reminder:2}
      _mcd_pwd 1
    fi

    if (( ${#reminder} )); then
      IFS="/" read -a parts <<< $reminder
      for part in $parts; do
        case $part in
          \.\.)
            _mcd_up 1
            (( $? )) && _mcd_die "${cantResolve}"; return 1
          ;;
          \.)
            ## nothing
          ;;
          *)
            _mcd_down ${part} 1
            (( $? )) && _mcd_die "${cantResolve}"; return 1
          ;;
        esac
      done
    fi
  fi

  pwd
#  echo "${originPath}"
}


function _mcd_up() {
  local doCd=$1

  if (( "$doCd" )); then
    if [[ $(_mcd_git_dir) == ".git" ]]; then
      _mcd_die "Can't up at the root module"
      return 1
    else
      _mcd_pwd 1
      cd ..
      _mcd_pwd 1
    fi
  else
    # TODO
    _mcd_die "not yet implemented"
  fi
}



function _mcd_down() {
  local path="$1"
  local doCd="$2"
  local ret=1

  while read -a module; do
    subModule="${module[0]}"
    localPath="${module[1]}"
    echo "$subModule" | grep -o "${path}" &> /dev/null
    local existsReverted=$?
    if (( ! $existsReverted )); then
      ret=0
      if (( $doCd )); then
        cd "$localPath"
      else
        echo $(_mcd_pwd)/"${localPath}"
      fi
      break
    fi
  done < <(git config -f .gitmodules --get-regexp "submodule.*.path" | sed -E "s/submodule\.(.*)\.path/\1/")

  return ${ret}
}


  #
  ## Print module directory
  ## just like Unix pwd, but for modules hierarchy
  #
function _mcd_pwd() {
  local path=$(git rev-parse --show-toplevel)
  local doCd="$1"
  if (( "$doCd" )); then
    cd "${path}"
  else
    echo "${path}"
  fi
}

function _mcd_git_dir() {
  local url=$(git rev-parse --git-dir)
  echo ${url}
}

_mcd_root() {
  local doCd="$1"
  local gitDir=$(_mcd_git_dir)
  local rootGitDir=${gitDir##*/}
  local root

  if [[ ${rootGitDir} == ".git" ]]; then
    root=$(git rev-parse --show-toplevel)
  else
    root="${gitDir%%/.git/*}"  > /dev/null
  fi

  if (( "$doCd" )); then
    cd "${root}"
  else
    echo "${root}"
  fi
}


function _mcd_help() {
cat << EOF

NAME:
    ${0##*/} status in git umbrella-managed modules

SYNOPSIS:
    '${0##*/} [<any-git-status-options>] [-v|--verbose] [<path-resolution>] -- [[<module-name>] ...]'

DESCRIPTION:


EXAMPLES:
    '${0##*/} -v .' -> show verbose status for current module only


OPTIONS:
      --help|-h|-\?
          get this help

      --
          marks state after which repositories will be shown in status.


EOF
}
