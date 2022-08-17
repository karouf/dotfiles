# Dotfiles

## Requirements
- git
- ruby

## Installation

```bash
mkdir -p $HOME/code
cd $HOME/code
git clone https://github.com/karouf/dotfiles.git
cd dotfiles
cp config.sample config
```

Edit variables in `config` and then install evrything:

```bash
./script/bootstrap
```
