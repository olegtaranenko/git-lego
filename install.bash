#!/usr/bin/env bash


typeset verbose=0
typeset profile=0
typeset force=0

show_help() {
  cat << EOF
	${0##*/} - install environment for consistentwork
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
      force=1
      ;;
    --no-force|-F)
      force=0
      ;;

    *)
      if [[ -z ${1%%-*} ]]; then
        echo "Unknown option '$1'"
	exit 1	
      elif [[ -z ${profile} ]]; then
        profile=$1
      fi
      ;;
  esac
  shift
done

# Arbitrary profile, maybe .bash_profile or .profile or something else...
if [[ -n $profile ]]; then
  if [[ ! ${profile} = '~/' ]]; then
    profile="~/"$profile
  fi
  if [[ ! -x $profile ]]; then
    unset profile
  fi
fi

[[ -z $profile ]] && [[ -f ~/.bash_profile ]] && profile=~/.bash_profile
[[ -z $profile ]] && profile=~/.profile
#echo $profile
#profile=$USERPROFILE/.profile
#profile=~/.profile
#cat ${profile}
(( $verbose )) && echo "profile='$profile'"
if [[ -e $profile ]] || (( $force )); then
  env | grep -s CWORK_HOME > /dev/null
  if (( ! $? )); then
    echo "CWORK_HOME environment is already installed to '$CWORK_HOME'" >&2
  else
    echo "CWORK_HOME environment is not installed, by default will be used ~/consistentwork" >&2
    echo "export CWORK_HOME=~/consistentwork" >> $profile
  fi
  echo $PATH | grep -E -o -q "\.consistentwork\/bin" > /dev/null
  if (( $? )); then
    cat << EOF >> $profile
if [[ -d ~/.consistentwork && -f ~/.consistentwork/.profile ]]; then
  . ~/.consistentwork/.profile
fi
EOF
  else 
    (( $verbose )) && echo "PATH already in order" >&2
  fi
else
  printf "$profile not exists. \nTry '${0##*/} --force' to create a bash profile file \nor '${0##*/} --help' for more information\n" >&2
fi


