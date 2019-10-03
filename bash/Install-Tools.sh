#curl faro binary, chmod +x 
xcode-select --install
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew doctor
brew install python@2 python
pip2 install virtualenv --upgrade
pip3 install virtualenv --upgrade
pip3 install black
pip3 install pylint
brew install openssl
brew install git
brew install gpg
brew install jq
brew install awscli
brew install tree
brew install watch
brew install shellcheck
brew install cfn-lint

brew tap caskroom/cask
brew cask install google-chrome
brew cask install adobe-acrobat-reader
brew cask install iterm2
brew cask install istat-menus
brew cask install bartender
brew cask install dropbox
brew cask install radiant-player
brew cask install vlc
brew cask install caffeine
brew cask install spectacle
brew cask install 1password
brew cask install keka
brew cask install flycut
brew cask install microsoft-teams
brew cask install powershell
brew cask install intellij-idea
brew cask install eclipse-ide
brew cask install telegram
brew cask install vmware-fusion

brew tap homebrew/cask-drivers
brew cask install logitech-options
brew cask install logitech-gaming-software
brew cask install logitech-unifying
brew cask install displaylink

brew tap homebrew/cask-versions
brew cask install microsoft-remote-desktop-beta

brew cask install visual-studio-code
code --install-extension ms-vscode.PowerShell
code --install-extension robertohuertasm.vscode-icons
code --install-extension ms-python.Python
code --install-extension EditorConfig.EditorConfig

touch ~/.profile
echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> ~/.profile
touch ~/.bashrc
echo 'export PS1="\[\033[38;5;2m\]\[\033[48;5;0m\]\h@\u [\w]:\\$ \[$(tput sgr0)\]"' >> ~/.bashrc
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
echo 'export PATH=/usr/local/bin:/usr/local/sbin:$PATH' >> ~/.bashrc
source .profile


ssh-keygen -t rsa





eval "$(ssh-agent -s)"
ssh-add -K ~/.ssh/id_rsa
git config --global user.name "Andy Schwabe"
git config --global user.email "andy.schwabe@infor.com"

gpg --full-generate-key
gpg --list-secret-keys --keyid-format LONG
gpg --armor --export <keyid>

git clone ssh://git@oxfordssh.awsdev.infor.com:7999/Andy.Schwabe/aschwabepersonal.git
git clone ssh://git@oxfordssh.awsdev.infor.com:7999/Michael.Hetzel/mhetzelpersonal.git

mkdir ops_repos
cd ops_repos/
git clone ssh://git@collab.aws.infor.com:7999/app/ips.git
git clone ssh://git@collab.aws.infor.com:7999/app/ts.git
git clone ssh://git@collab.aws.infor.com:7999/ama/account.git
git clone ssh://git@collab.aws.infor.com:7999/ama/cfgmgmt.git
git clone ssh://git@collab.aws.infor.com:7999/ama/mon.git
git clone ssh://git@oxfordssh.awsdev.infor.com:7999/TS/Infrastructure.git
git clone ssh://git@oxfordssh.awsdev.infor.com:7999/infraops/ssm.git
git clone ssh://git@oxfordssh.awsdev.infor.com:7999/cts/cicd/faro-services.git