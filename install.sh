#!/usr/bin/env bash
pkg update -y || true
pkg upgrade -y || true
pkg install -y git curl wget neovim
echo "[TP] Base install done."
