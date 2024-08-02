#!/bin/bash

# check if names below exist, rename them to bak
[[ -e ~/.config ]] && mv ~/.config ~/.config.bak
[[ -e ~/.tmux ]] && mv ~/.tmux ~/.tmux.bak
[[ -e ~/.zshrc ]] && mv ~/.zshrc ~/.zshrc.bak

ln -s ~/devenv/dotfiles/.config ~/.config
ln -s ~/devenv/dotfiles/.tmux ~/.tmux
ln -s ~/devenv/dotfiles/.zshrc ~/.zshrc

