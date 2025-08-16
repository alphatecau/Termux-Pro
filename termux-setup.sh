#!/bin/bash

# 🚀 Termux-Pro Setup Script
echo "[*] Updating Termux..."
apt update -y && apt upgrade -y

echo "[*] Installing essential packages..."
pkg install -y git curl wget python nodejs vim openssh clang make

echo "[*] Adding helpful aliases..."
echo "alias ll=\"ls -la\"" >> ~/.bashrc

echo "[*] Setup complete! 🎯"
echo "Restart Termux or run: source ~/.bashrc"
echo "You now have a professional Termux environment ready!"
