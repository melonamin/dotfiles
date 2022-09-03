# Dotfiles

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

## Extra

Use `~/.extra`for things you don't want to commit.

My `~/.extra` looks something like this:

```bash
# Git credentials
export GIT_AUTHOR_NAME="Alex Mazanov"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
git config --global user.name "$GIT_AUTHOR_NAME"
export GIT_AUTHOR_EMAIL="alexandr.mazanov@gmail.com"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
git config --global user.email "$GIT_AUTHOR_EMAIL"

export GITHUB_TOKEN="blablabla"
```
### Sensible macOS defaults

When setting up a new Mac, you may want to set some sensible macOS defaults:

```bash
./.macos
```

### Install Homebrew formulae

Brew formulae and casks are installed using brew bundle, from `Brewfile`:

```bash
brew bundle install
```
