You are ready to work for CONSISTENTWORK developer environment
Pleas add to ~/.profile or ~/.bash_profile following snippet

if [ -d ~/.consistentwork -a -f ~/.consistentwork/.profile ]; then
  source ~/.consistentwork/.profile
fi