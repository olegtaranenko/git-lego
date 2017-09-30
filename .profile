#!/usr/bin/env bash

if [ -z $CWORK_HOME ]; then
  # path where consistentwork projects are cloned
  export CWORK_HOME=~/consistentwork
fi
export PATH="~/.consistentwork:$CWORK_HOME/bin:$PATH"


# preference to locally built git
# see https://gist.github.com/digitaljhelms/2931522 or https://github.com/git/git/blob/master/INSTALL how to build
# option make prefix=~ is being used
#
## WARNING: no use self-compiled git, because git subrepo is broken in this case
#
#if [ -f ~/bin/nogit ]; then
#  if [ "$(git --version)" != "$(~/bin/git --version)" ]; then
#    export PATH="~/bin:$PATH"
#  fi
#fi

#. $HOME/.consistentwork/bin/lib/mfs.sh