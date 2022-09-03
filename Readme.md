#Dotfiles

## Getting Started

```bash
git init --bare $HOME/.cfg
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
config config --local status.showUntrackedFiles no
```

Tha same in one line:

```bash
curl -Lks https://gist.githubusercontent.com/melonamin/fad2bfa0ae272aad18d02999907dbb2a/raw/bc88daec72dacd19d67dab64c75ffd84b81714d9/init.sh | /bin/zsh
```

## When you alreade have a repo

On new machine

```bash
git clone --bare <git-repo-url> $HOME/.cfg
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
config checkout
```
