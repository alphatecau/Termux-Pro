

---

About the Project

Termux-Pro is a curated toolkit designed to extend Termux capabilities far beyond standard Linux-on-Android usage.
It combines optimized shell scripts, secure environment configurations, and advanced automation routines for developers, penetration testers, system architects, and AI enthusiasts.

With Termux-Pro, users gain an all-in-one environment that supports:

Development workflows

AI integrations

System automation

Security-hardening best practices

Modular extensibility



---

Features

One-Line Installation for rapid deployment

Pre-Configured Security Hardening with ulimit, umask, and file permissions

Optimized Aliases & Power Commands for navigation and Git operations

Module Management for dynamic expansions and custom scripts

Cross-Compatible with Debian/Ubuntu packages

AI-Ready Integration Hooks for GPT-powered utilities



---

Installation

Fully automated one-liner:

pkg update -y && pkg upgrade -y && pkg install -y git wget curl nano unzip proot && git config --global user.name "alphatecau" && git config --global user.email "alpha.tec.au86@gmail.com" && rm -rf Termux-Pro && git clone https://github.com/alphatecau/Termux-Pro && cd Termux-Pro && bash install.sh && echo -e "alias ll='ls -alF'\nalias la='ls -A'\nalias l='ls -CF'\nalias gs='git status'\nalias gp='git pull'\nalias gc='git commit'\nexport TERMUX_AI_HOOK=1\nexport PATH=$HOME/Termux-Pro/modules:$PATH" >> ~/.bashrc && chmod 700 ~/.bashrc && source ~/.bashrc && echo 'ulimit -n 65535' >> ~/.profile && echo 'umask 027' >> ~/.profile && source ~/.profile

Steps:

1. Open Termux.


2. Copy and paste the one-liner.


3. Press Enter.


4. Once finished, aliases, AI hooks, module paths, and security configurations are applied automatically.




---

Aliases

ll  # List all files with details
la  # List all files except . and ..
l   # List files in columns
gs  # Git status
gp  # Git pull
gc  # Git commit


---

AI Integration

TERMUX_AI_HOOK=1 enables GPT-powered scripts.

Modular AI scripts can be placed in $HOME/Termux-Pro/modules.



---

Security Hardening

ulimit -n 65535 → high file descriptor limit for resource-intensive tasks

umask 027 → default secure permissions for new files

.bashrc permissions set to 700 → prevent unauthorized edits



---

Modular Architecture

Place custom scripts or modules in ~/Termux-Pro/modules

Automatically included in $PATH for instant execution



---

Installed Utilities

git → version control

wget → file downloads

curl → HTTP requests

nano → text editing

unzip → archive handling

proot → containerized environments



---

Usage

Use aliases immediately:


ll
gs
gp

Add custom scripts to ~/Termux-Pro/modules and run them directly:


my_custom_script.sh

Update Termux-Pro:


cd ~/Termux-Pro
git pull
bash install.sh


---

Security Notes

GitHub PAT is stored securely in ~/.git-credentials.

Avoid sharing your Termux environment with untrusted users.

Regularly update system and repository:


pkg update -y && pkg upgrade -y


---

Contribution

1. Fork the repository


2. Create a branch: git checkout -b feature/your-feature


3. Make your changes


4. Commit: git commit -m "Add your feature"


5. Push: git push origin feature/your-feature


6. Create a Pull Request




---

License

MIT License


---

Support

For support, open an issue:
Termux-Pro Issues


---

