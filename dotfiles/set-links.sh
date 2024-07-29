#!/bin/bash

# check if names below exist, rename them to bak
if [ -e ~/.config] ; then mv ~/.config ~/.config.bak; fi
if [ -e ~/.tmux] ; then mv ~/.tmux ~/.tmux.bak; fi
if [ -e ~/.zshrc] ; then mv ~/.zshrc ~/.zshrc.bak; fi

ln -s ~/devenv/dotfiles/.config ~/.config
ln -s ~/devenv/dotfiles/.tmux ~/.tmux
ln -s ~/devenv/dotfiles/.zshrc ~/.zshrc

