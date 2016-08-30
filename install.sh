#!/usr/bin/env bash

env | grep -s CWORK_HOME
if [[ ! $? ]]; then
  echo "CW environment is already installed"
  exit 0
fi

profile=$1
if [[ -n $profile ]]; then
  if [[ ! ${profile} =~ '~/' ]]; then
    profile="~/"$profile
  fi
  if [[ ! -x $profile ]]; then
    profile=""
  fi
fi

[[ -z $profile ]] && [[ -f "~/.bash_profile" ]] && profile="~/.bash_profile"
if [[ -z $profile  && ! -f "~/.profile" ]]; then
  profile="~/.profile"
fi
echo $profile
exit 0
if [[ -x $profile ]]; then
  echo << 'EOF' >> $profile
  if [[ -d ~/.consistentwork && -f ~/.consistentwork/.profile ]]; then
    . ~/.consistentwork/.profile
  fi
EOF
fi