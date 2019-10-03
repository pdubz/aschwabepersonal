export PS1="\[\033[38;5;2m\]\u@\h:[\w]\n\$ \[$(tput sgr0)\]"
export GOPATH=$HOME/go/
export PATH=$PATH:$HOME/bin:$GOPATH
export JAVA_HOME=$(/usr/libexec/java_home)
export STACK='green'
export ENVIRONMENT='dev'
export ACMCERTIFICATEARN='arn:aws:acm:us-east-1:628657941405:certificate/c25fe95f-d9b7-46d4-b19f-0e15832dc5ca'
export REGION='us-east-2'
alias dkrun='docker container run -it --rm'
alias cdrt='cd ~/go/src/github.com/AndySchwabe/responsetime/'
alias vi=vim
alias rmds="find . -name '.DS_Store' -type f -delete"
alias ssheuc1='ssh -p 27 aschwabe@euc1-ssh.awsdev.infor.com'
alias sshuse1='ssh -p 27 aschwabe@ssh.awsdev.infor.com'
alias build_push="docker system prune -fa && cd ~/dockerfiles && find . -name '.DS_Store' -type f -delete && ./build.sh && ./build_aws.sh"
alias ll="exa -al"
export HISTTIMEFORMAT="%h %d %H:%M:%S "
export HISTSIZE=10000
export HISTFILESIZE=10000

[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"
# added by travis gem
[ -f /Users/andy/.travis/travis.sh ] && source /Users/andy/.travis/travis.sh
