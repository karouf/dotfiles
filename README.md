# Dotfiles

## Requirements
- git
- ruby
- [homemaker](https://github.com/FooSoft/homemaker)

## Installation

```bash
mkdir -p $HOME/code
cd $HOME/code
git clone https://github.com/karouf/dotfiles.git
cd dotfiles
bin/homestage vars:bootstrap
mv variables.sample.yml variables.yml
```

Edit variables in `variables.yml` and then install everything:

```bash
bin/homestage do <profile>
```
