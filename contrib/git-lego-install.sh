#!/usr/bin/env bash


	# load common functionality
#	. "$GITFLOW_DIR/gitflow-common"

	# This environmental variable fixes non-POSIX getopt style argument
	# parsing, effectively breaking git-flow subcommand parsing on several
	# Linux platforms.
	export POSIXLY_CORRECT=1

	# use the shFlags project to parse the command line arguments
#	. "$GITFLOW_DIR/gitflow-shFlags"
	FLAGS_PARENT="git flow"

# The sed expression here replaces all backslashes by forward slashes.
# This helps our Windows users, while not bothering our Unix users.
export GITLEGO_DIR=$(dirname "$(echo "$0" | sed -e 's,\\,/,g')")

# MacPorts place git sources to /opt/local/share/git folder
SHARED_GIT_DIR=/opt/local/share/git
COMPLETION_DIR=${SHARED_GIT_DIR}/contrib/completion
COMPLETION_SH=${COMPLETION_DIR}/git-completion.bash
# PROMPT_SH=${COMPLETION_DIR}/git-prompt.sh

#if [ -f ${COMPLETION_SH} ]; then
#  source ${COMPLETION_SH}
#fi



typeset verbose=0
typeset PROFILE
typeset doForce=0

show_help() {
  cat << EOF

	${0##*/} [.profile|.bash_profile|.bashrc|... any other shell script ...]

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
    echo "${COMPLETION_SH} does not have executable flag."
    echo "You maybe required enter admin password"
    sudo chmod +x ${COMPLETION_SH}
  fi

  if [[ -f "$PROFILE" ]] && grep -q "${COMPLETION_SH}" "$PROFILE"; then
	echo "git-completion.bash already added to the profile."
  else
	echo "Adding git-completion.bash to the profile..."
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
  echo "Updating profile='${PROFILE}' ... " >&2
#  env | grep -s GIT_LEGO_HOME > /dev/null
#  if (( ! $? )); then
#    echo "GIT_LEGO_HOME environment is already installed to '$GIT_LEGO_HOME'" >&2
#  else
#    echo "GIT_LEGO_HOME environment is not installed" >&2
#    echo "export GIT_LEGO_HOME=$GL_BIN" >> ${PROFILE}
#  fi
  alreadyExists=$( echo $PATH | grep -o "$GL_BIN" )
  if [[ -z "$alreadyExists" ]]; then
    echo "Update PATH variable to $PROFILE" >&2
    cat << EOT >> ${PROFILE}
export PATH="$GL_BIN:\$PATH"
EOT
  else
    echo "Looks like git-lego environment installed int PATH already in $alreadyExists" >&2
  fi
else
  printf "${PROFILE} not exists. \nTry '${0##*/} --force' to create a bash profile file \nor '${0##*/} --help' for more information\n" >&2
fi
