You are ready to work for CONSISTENTWORK developer environment

To setup environment run command:
    cd ~/.consistentwork
    ./install.bash

---------------- need to be removed -----------------------
It should add to ~/.profile or ~/.bash_profile following snippet

### NOTE: if you prefer other place for CW project edit following snippet
export CWORK_HOME=~/consistentwork

### this required to get git-umbrella scripts working
if [ -d ~/.consistentwork -a -f ~/.consistentwork/.profile ]; then
  source ~/.consistentwork/.profile
fi

