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
if [ -f ~/bin/git ]; then
  if [ "$(git --version)" != "$(~/bin/git --version)" ]; then
    export PATH="~/bin:$PATH"
  fi
fi
