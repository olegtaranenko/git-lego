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
      pushd $pathResolution &>/dev/null
      pathNotFound=${#paths[@]}
      for path in ${paths[@]}; do
        pathNotFound=0
        pathResolution=$(_m_path_resolution "$path" "$strict")
        [[ -z $pathResolution ]] && pathNotFound=1
        if (( ! $pathNotFound )); then
          break
        fi
      done
      popd &>/dev/null
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
    [[ -z ${1%%-*}  ]] && return 1
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
    [[ -z ${1%%-*}  ]] && return 1
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

  pushd . &>/dev/null
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
  popd &>/dev/null
  _m_finalize
  return ${ret}
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

