#!/usr/bin/env bash


export POSIXLY_CORRECT=1


# The sed expression here replaces all backslashes by forward slashes.
# This helps our Windows users, while not bothering our Unix users.
export GITLEGO_DIR=$(dirname "$(echo "$0" | sed -e 's,\\,/,g')")

# MacPorts place git sources to /opt/local/share/git folder
SHARED_GIT_DIR=/opt/local/share/git
COMPLETION_DIR=${SHARED_GIT_DIR}/contrib/completion
COMPLETION_SH=${COMPLETION_DIR}/git-completion.bash
# PROMPT_SH=${COMPLETION_DIR}/git-prompt.sh

typeset verbose=0
typeset PROFILE
typeset doForce=0

show_help() {
  cat << EOF

	${0##*/} [.profile|.bash_profile|.bashrc|... any other shell script ...] [--force]

      Install environment for git lego to specified profile file.
	    By default (no profile given) script will look into first existing files in above list
	    Note, that profile has to be executable.

EOF
}

#set -x
while [[ -n $1 ]]; do
  case $1 in
    -h|-\?|--help)
      show_help
      exit
      ;;
    -v|--verbose)
      verbose=$((verbose + 1)) # Each -v argument adds 1 to verbosity.
      ;;

    --force|-f)
      doForce=1
      ;;
    --no-force|-F)
      doForce=0
      ;;

    *)
      if [[ -z ${1%%-*} ]]; then
        echo "Unknown option '$1'"
    	exit 1
      elif [[ -z ${PROFILE} ]]; then
        PROFILE=$1
      fi
      ;;
  esac
  shift
done

# Arbitrary profile, maybe .bash_profile or .profile or something else...
if [[ -n ${PROFILE} ]]; then
  if [[ ! ${PROFILE} = '~/' ]]; then
    PROFILE="~/"${PROFILE}
  fi
  if [[ ! -x ${PROFILE} ]]; then
    unset profile
  fi
fi

[[ -z ${PROFILE} ]] && PROFILE=~/.profile
[[ -z ${PROFILE} ]] && [[ -f ~/.bash_profile ]] && PROFILE=~/.bash_profile


SHARED_GIT_DIR=/opt/local/share/git
COMPLETION_DIR=${SHARED_GIT_DIR}/contrib/completion
COMPLETION_SH=${COMPLETION_DIR}/git-completion.bash
# PROMPT_SH=${COMPLETION_DIR}/git-prompt.sh

#echo ${PROFILE}


if [ -f ${COMPLETION_SH} ]; then
  if [ ! -x ${COMPLETION_SH} ]; then
    echo "${COMPLETION_SH} does not have executable flag." >&2
    echo "You maybe required enter admin password" >&2
    sudo chmod +x ${COMPLETION_SH}
  fi

  if [[ -f "$PROFILE" ]] && grep -q "${COMPLETION_SH}" "$PROFILE"; then

  	echo "git-completion.bash already added to the profile." >&2
  else
  	echo "Adding git-completion.bash to the profile..." >&2
    cat << EOT >> ${PROFILE}

# added by ${0##*/}
. ${COMPLETION_SH}
EOT

  fi

fi


INSTALL_SCRIPT_DIR=$( dirname $0 )
cd $INSTALL_SCRIPT_DIR/..
GL_BIN=$( pwd )

if [[ -e ${PROFILE} ]] || (( $doForce )); then
  if [[ "$doForce" == 1 && -z $PROFILE ]]; then
    PROFILE="~/.profile"
  fi
#  env | grep -s GIT_LEGO_HOME > /dev/null
#  if (( ! $? )); then
#    echo "GIT_LEGO_HOME environment is already installed to '$GIT_LEGO_HOME'" >&2
#  else
#    echo "GIT_LEGO_HOME environment is not installed" >&2
#    echo "export GIT_LEGO_HOME=$GL_BIN" >> ${PROFILE}
#  fi
  alreadyExists=$( echo $PATH | grep -o "$GL_BIN")
  if [[ -z "$alreadyExists" ]]; then
    echo "Updating profile '${PROFILE}' ... " >&2
    typeset NEW_PATH="$GL_BIN:\$PATH"
    echo "PATH variable updated to $NEW_PATH" >&2
    ts=$( date )
    cat << EOT >> ${PROFILE}
#added by '$0' script at $ts
export PATH=$NEW_PATH
EOT
    if (( ! $? )); then
      echo "git-lego environment installed. Not forget to reopen the terminal window" >&2
    else
      echo "Something wrong with git-lego environment installation" >&2
    fi
  else
    echo "Looks like git-lego environment already installed in $GL_BIN" >&2
  fi
else
  printf "${PROFILE} not exists. \nTry '${0##*/} --force' to create a bash profile file \nor '${0##*/} --help' for more information\n" >&2
fi
