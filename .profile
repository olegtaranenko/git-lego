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

function _mcd_help() {
name=$1

cat << EOF

NAME:
    '${name##*/} - module change directory

SYNOPSIS:
    '${name##*/} [options] [--[no-]fuzzy|-Z|-z] [<path-resolution>]

DESCRIPTION:

EXAMPLES:
EOF

_m_help_options
}

mcd() {
  local paths=() scopes=() fuzzes=([0]="^") first fuzzy=0
  while [[ -n $1 ]]; do
    case $1 in
      -h|-\?|--help)
        _mcd_help  $FUNCNAME
        return 0
        ;;
      -v|--verbose)
        verbose=$((verbose + 1))
        ;;

      --fuzzy|-z)
        fuzzy=1
        ;;
      --no-fuzzy|-Z)
        fuzzy=0
        ;;

      *)
        if [[ -z ${1%%-*} ]]; then
          _m_die "wrong option '$1'"
          return 1
        else
          if [[ -z $first ]]; then
            first=$1
            if [[ -n ${first%%/*} && -n ${first%%../*} && $first != ".." && -n ${first%%./*} && $first != "." ]]; then
              scopes+=("." "/")
              paths+=($1)
            else
              local len=2
              if [[ ${first:0:2} == ".." ]]; then
                len=3
              fi
              scopes+=(${first:0:($len-1)})
              paths+=(${first:$len})
            fi
          else
            paths+=($1)
          fi
        fi
        ;;
    esac
    shift
  done
#  echo " scopes: ${scopes[@]}" >&2
#  echo " paths: ${paths[@]}" >&2

  _m_not_git_repository; (( $? )) && return 1

  if (( ! $fuzzy )); then
    unset fuzzy
    fuzzes+=("")
  else
    fuzzy="^"
  fi

  if (( ! ${#scopes[@]} )); then
    scopes+=(".")
  fi

  local scopeNotFound=1 pathNotFound=0 pathResolution notFound=1
  for scope in ${scopes[@]}; do
    pathResolution=$(_m_path_resolution "${scope}")
    scopeNotFound=$?

    if (( ! $scopeNotFound )); then
      pushd $pathResolution &> /dev/null
      pathNotFound=${#paths[@]}
      for path in ${paths[@]}; do
        pathResolution=$(_m_path_resolution "${path}" "$fuzzy")
        pathNotFound=$?
        if (( ! $pathNotFound )); then
          break
        fi
      done
      popd &> /dev/null
    fi

    if (( ! $scopeNotFound )) && (( ! $pathNotFound )); then
      notFound=0
      break
    fi
  done

  if (( ! $notFound )); then
    cd $pathResolution
    _m_pmd
  else
    local dieMsg="Can't resolve module path '${paths[@]}'"
    if (( $verbose )); then
      dieMsg+=" in scopes '${scopes[@]}'"
    fi
    if [[ -n ${fuzzy} ]]; then
      dieMsg+=", FUZZY mode"
    fi
    _m_die "${dieMsg}"
  fi
  
  (( $verbose )) && echo $pathResolution >&2

  _m_finalize
  return $notFound
}

function _pmd_help() {
name=$1

cat << EOF

NAME:
    '${name##*/} - show current module directory

SYNOPSIS:
    '${name##*/} [options] [<path-resolution>]

DESCRIPTION:
    doesn't change current directory

EXAMPLES:
    '${name##*/} -v .' -> show verbose status for current module only
EOF

_m_help_options
}

pmd() {
  while [[ -n $1 ]]; do
    (( $stopOptions )) && [[ -z ${1%%-*}  ]] && return 1
    case $1 in
      -h|-\?|--help)
        _pmd_help $FUNCNAME
        return 0
        ;;
      -v|--verbose)
        verbose=$((verbose + 1))
        ;;

      *)
        _m_die "wrong option '$1'"
        return 1
        ;;
    esac
    shift
  done

  _m_not_git_repository; (( $? )) && return 1

  _m_pmd

  _m_finalize
}


function _mls_help() {
name=$1

cat << EOF

NAME:
    '${name##*/} - list child modules

SYNOPSIS:
    '${name##*/} [options] [--[no-]recursive|-R|-r] [<path-resolution>]

DESCRIPTION:

EXAMPLES:
    '${name##*/} .' -> show verbose status for current module only
EOF

_m_help_options
}

mls() {
  path=$1
  while [[ -n $1 ]]; do
    (( $stopOptions )) && [[ -z ${1%%-*}  ]] && return 1
    case $1 in
      -h|-\?|--help)
        _mls_help  $FUNCNAME
        return 0
        ;;
      -v|--verbose)
        verbose=$((verbose + 1)) 
        ;;
      -r|--recursive)
        recursive=$((recursive + 1)) 
        ;;

      *)
        if [[ -z ${1%%-*} ]]; then
          _m_die "wrong option '$1'"
          return 1
        fi
        ;;
    esac
    shift
  done

  _m_not_git_repository; (( $? )) && return 1

  local path=$(_m_path_resolution "$path")
  pushd "${path}" &> /dev/null
  _m_mls
  popd &> /dev/null
  _m_finalize
  return ${ret}
}


function _m_finalize() {
  unset fuzzy
  unset verbose
  unset recursive
  set +x
}

function _m_mls() {
  while read -a module; do
    subModule="${module[0]}"
    localPath="${module[1]}"
    pushd "$localPath" &> /dev/null
    _m_pmd

    if (( $recursive )); then
      _m_mls
    fi

    popd &> /dev/null
  done < <(git config -f .gitmodules --get-regexp "submodule.*.path" | sed -E "s/submodule\.(.*)\.path/\1/")
}

function _m_not_git_repository() {
  git rev-parse --git-dir &> /dev/null
  if (( $? )); then
    echo "Not a git repository" >&2
    return 1
  fi
  return 0
}


function _m_pmd() {
  local gitDir=$(_m_git_dir)
  gitDir=${gitDir##*.git/}
  local path
  IFS="/" read -a names <<< ${gitDir}

  for name in ${names[@]}; do
    if [ ${name} != "modules" -a $name != ".git" ]; then
      path+=/"$name"
    fi
  done

  [[ -z $path ]] && path="/"
  echo  "${path}"
}


function _m_die() {
  echo $1 >&2
  _m_finalize
}


function _m_path_resolution() {
  if [[ $1 != "." ]]; then
    local originPath reminder="$1"
    local fuzzy=$2

    if [[ -n ${reminder} ]]; then
  #    if [[ -n ${reminder%%/*} && -n ${reminder%%../*} && $reminder != ".." && -n ${reminder%%./*} && $reminder != "." ]]; then
  #      reminder="./$reminder"
  #    fi

      if [[ -z ${reminder%%/*} ]]; then
        _m_root 1
        reminder=${reminder:1}
      elif [[ -z ${reminder%%../*} || $reminder == ".." ]]; then
        reminder=${reminder:3}
        _m_pwd 1
        _m_up 1
        (( $? )) && die "${cantResolve}"
      elif [[ -z ${reminder%%./*} || $reminder == "." ]]; then
        reminder=${reminder:2}
        _m_pwd 1
      fi

      if (( ${#reminder} )); then
        IFS="/" read -a parts <<< $reminder
        for part in $parts; do
          case $part in
            \.\.)
              _m_up 1
              if (( $? )); then
#                _m_die "${cantResolve}"
                return 1
              fi
            ;;
            \.)
              ## nothing
            ;;
            *)
              _m_down ${part} 1 $fuzzy
              if (( $? )); then
#                _m_die "${cantResolve}"
                return 1
              fi
            ;;
          esac
        done
      fi
    fi
  else
    _m_pwd 1
  fi

  pwd
}


function _m_up() {
  local doCd=$1

  if (( "$doCd" )); then
    if [[ $(_m_git_dir) == ".git" ]]; then
      _m_die "Can't up at the root module"
      return 1
    else
      _m_pwd 1
      cd ..
      _m_pwd 1
    fi
  else
    # TODO
    _m_die "not yet implemented"
  fi
}



function _m_down() {
  local path="$1"
  local doCd="$2"
  local ret=1
  local fuzzy="$3"

  if [[ -n $fuzzy ]]; then
    path=${fuzzy}${path}
  fi

  while read -a module; do
    subModule="${module[0]}"
    localPath="${module[1]}"
    echo "$subModule" | grep "${path}" &> /dev/null
    local existsReverted=$?
    if (( ! $existsReverted )); then
      ret=0
      if (( $doCd )); then
        cd "$localPath"
      else
        echo $(_m_pwd)/"${localPath}"
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
function _m_pwd() {
  local path=$(git rev-parse --show-toplevel)
  local doCd="$1"
  if (( "$doCd" )); then
    cd "${path}"
  else
    echo "${path}"
  fi
}

function _m_git_dir() {
  local url=$(git rev-parse --git-dir)
  echo ${url}
}

function _m_root() {
  local doCd="$1"
  local gitDir=$(_m_git_dir)
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


function _m_help_options() {
cat << EOF
    '${name##*/} -v' -> switch on show verbose status
    '${name##*/} -v -v' -> more verbose information

OPTIONS:
      --help|-h|-\?
          get this help

      --verbose|-v
          more information to output

EOF
}

