#!/bin/bash

# 1. Define all required packages for Arch
# GUI/Terminal: xorg-server, xorg-xinit, i3-wm, alacritty, dmenu, xterm
# Automation: xdotool, xbindkeys, wmctrl
needed_packages=(
    git rsync fzf neovim lua luarocks clang
    gcc inetutils openssh base-devel tmux unzip
    rust deno nodejs npm python
    xorg-server xorg-xinit i3-wm alacritty dmenu xterm
    xdotool xbindkeys wmctrl
)

echo "--- Checking system dependencies... ---"

# Detect if we need sudo or if we are root
if [ "$EUID" -eq 0 ]; then
    PACMAN="pacman -Sy --needed --noconfirm"
else
    if ! command -v sudo &> /dev/null; then
        echo "Error: sudo is not installed and you are not root."
        exit 1
    fi
    PACMAN="sudo pacman -Sy --needed --noconfirm"
fi

# Install the packages
$PACMAN "${needed_packages[@]}"

# 2. Directory & Repo Logic
if [ "$(basename "$PWD")" != "dev" ]; then
    echo "Current directory is NOT 'dev'. Checking for repo..."
    if [ ! -d "dev" ]; then
        echo "--- Cloning dev repository... ---"
        git clone https://www.github.com/gitdexgit/dev
    fi
    echo "--- Entering dev directory... ---"
    cd dev || { echo "Failed to enter dev directory. Exiting."; exit 1; }
fi

# 3. Oh My Zsh Installation
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "--- Oh My Zsh not found. Installing... ---"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
fi

# 4. Clone fzf-tab plugin
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ]; then
    echo "--- Cloning fzf-tab plugin... ---"
    git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"
fi

# 5. Sync Custom Oh My Zsh components
if [ -d ".oh-my-zsh" ]; then
    echo "--- Merging custom .oh-my-zsh files... ---"
    rsync -a .oh-my-zsh/ ~/.oh-my-zsh/
fi

# 6. General Dotfile & Script Sync
echo "--- Starting dotfile and script rsync... ---"
mkdir -p ~/.config ~/.local/share

# Sync standard dotfiles
rsync -a .zshrc ~/
rsync -a .zshenv ~/
rsync -a .tmux.conf ~/
rsync -a .tmux ~/
rsync -a .Xresources ~/

# Sync xbindkeys (checks for both common filenames)
[ -f ".xbindkeysrc" ] && rsync -a .xbindkeysrc ~/
[ -f ".xbindkeys" ] && rsync -a .xbindkeys ~/

# Sync your scripts folder
if [ -d "scripts" ]; then
    echo "--- Syncing scripts to ~/scripts ---"
    rsync -a scripts/ ~/scripts/
fi

# Sync config directories
[ -d ".config" ] && rsync -a .config/ ~/.config/
[ -d ".local/share/fonts" ] && rsync -a .local/share/fonts ~/.local/share/

# 7. Neovim Config Check & Clone
if [ ! -d "$HOME/.config/nvim" ] || [ -z "$(ls -A "$HOME/.config/nvim")" ]; then
    echo "--- Neovim config missing or empty. Cloning from GitHub... ---"
    mkdir -p "$HOME/.config/nvim"
    git clone https://www.github.com/gitdexgit/nvim "$HOME/.config/nvim"
fi

# 8. Check/Create .xinitrc
if [ ! -f "$HOME/.xinitrc" ]; then
    echo "--- Creating basic .xinitrc... ---"
    cat <<EOF > "$HOME/.xinitrc"
#!/bin/sh

# Load Xresources (colors, fonts for xterm/urxvt)
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources &

# Set environment variables
export TERMINAL=alacritty
export EDITOR=nvim

# VM Support: Start spice-vdagent for clipboard/display sync
if command -v spice-vdagent > /dev/null; then
    spice-vdagent &
fi

# Start automation tools
[ -f ~/.xbindkeysrc ] && xbindkeys &
[ -f ~/.xbindkeys ] && xbindkeys -f ~/.xbindkeys &

# Execute Window Manager
exec i3
EOF
    chmod +x "$HOME/.xinitrc"
fi

echo "--- Setup Complete! ---"
echo "--- System Info ---"
echo "Hostname IP: $(hostname -i)"
echo "Type 'startx' to launch i3 with your synced configs."
