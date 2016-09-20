#!/usr/bin/env bash

function _mcd_help() {
name=$1

cat << EOF

NAME:
    '${name##*/} - module change directory

SYNOPSIS:
    '${name##*/} [options] [--[no-]strict|-Z|-z] [<path-resolution>]

DESCRIPTION:

EXAMPLES:
EOF

_m_help_options
}

mcd() {
  local paths=() scopes=() fuzzes=([0]="^") first strict=0
  while [[ -n $1 ]]; do
    case $1 in
      -h|-\?|--help)
        _mcd_help  $FUNCNAME
        return 0
        ;;
      -v|--verbose)
        verbose=$((verbose + 1))
        ;;

      --strict|-s)
        strict=1
        ;;
      --no-strict|-S)
        strict=0
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

  if (( ! $strict )); then
    unset strict
    fuzzes+=("")
  else
    strict="^"
  fi

  if (( ! ${#scopes[@]} )); then
    scopes+=(".")
  fi

  local scopeNotFound=1 pathNotFound=0 pathResolution notFound=1
  for scope in ${scopes[@]}; do
    scopeNotFound=0
    pathResolution=$(_m_path_resolution "${scope}")
    [[ -z $pathResolution ]] && scopeNotFound=1
    if (( ! $scopeNotFound )); then
      pushd $pathResolution &> /dev/null
      pathNotFound=${#paths[@]}
      for path in ${paths[@]}; do
        pathNotFound=0
        pathResolution=$(_m_path_resolution "$path" "$strict")
        [[ -z $pathResolution ]] && pathNotFound=1
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
    local dieMsg="Can't resolve path "
    if (( ${#paths[@]} )); then
      dieMsg+="'${paths[@]}'"
    else
      local noScopes=1
      dieMsg+="'${scopes[@]}'"
    fi
    if (( $verbose )) && (( ! $noScopes )); then
      dieMsg+=" in scopes '${scopes[@]}'"
    fi
    if [[ -n ${strict} ]]; then
      dieMsg+=", STRICT mode"
    fi
    _m_die "${dieMsg}"
    return 1
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

  #
  ## Print module directory
  ## just like Unix pwd, but for modules hierarchy
  #

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
  local path=$1
  local ret=0
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

  pushd . &> /dev/null
  path=$(_m_path_resolution "$path")
  if [[ -z $path ]]; then
    local dieMsg="wrong path resolution"
    (( $verbose )) && dieMsg+=", current path is $(_m_pmd)"
    _m_die "${dieMsg}"
    ret=1
  fi

  if (( ! "$ret" )); then
    cd "${path}"
    _m_mls
  fi
  popd &> /dev/null
  _m_finalize
  return ${ret}
}


function _m_finalize() {
  unset strict
  unset verbose
  unset recursive
  set +x
}

function _m_mls() {
  local ret=0
  while read -a module; do
    subModule="${module[0]}"
    localPath="${module[1]}"
    pushd "$localPath" &> /dev/null
    _m_pmd

    if (( $recursive )); then
      _m_mls && ret=1
    fi

    popd &> /dev/null
  done < <(git config -f .gitmodules --get-regexp "submodule.*.path" | sed -E "s/submodule\.(.*)\.path/\1/")
  return ${ret}
}

function _m_not_git_repository() {
  git rev-parse --git-dir &> /dev/null
  if (( $? )); then
    _m_die "Not a git repository"
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
  local originPath reminder="$1"
  if [[ ${reminder} != "." && -n ${reminder} ]]; then
    local strict=$2

    if [[ -n ${reminder} ]]; then

      if [[ -z ${reminder%%/*} ]]; then
        _m_root 1; (( $? )) && return 1
        reminder=${reminder:1}
      elif [[ -z ${reminder%%../*} || $reminder == ".." ]]; then
        reminder=${reminder:3}
        _m_pwd 1
        _m_up 1; (( $? )) && return 1
      elif [[ -z ${reminder%%./*} || $reminder == "." ]]; then
        reminder=${reminder:2}
        _m_pwd 1
      fi

      if (( ${#reminder} )); then
        IFS="/" read -a parts <<< $reminder
        for part in $parts; do
          case $part in
            \.\.)
              _m_up 1; (( $? )) && return 1
            ;;
            \.)
              ## nothing
            ;;
            *)
              _m_down ${part} 1 $strict; (( $? )) && return 1
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

  if [[ "$doCd" == 1 ]]; then
    if [[ $(_m_git_dir) == ".git" ]]; then
      echo "Can't up at the root module" >&2
      return 1
    else
      _m_pwd 1
      cd ..
      _m_pwd 1
    fi
  else
    # TODO
    echo "mode '$FUNCNAME $1' not yet implemented" >&2
    return 1
  fi
}



function _m_down() {
  local path="$1"
  local doCd="$2"
  local ret=1
  local strict="$3"

  if [[ -n $strict ]]; then
    path=${strict}${path}
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

