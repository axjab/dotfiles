#!/bin/bash
#
#     █████╗ ██╗     ██╗ █████╗  ██████╗███████╗ ██████╗
#    ██╔══██╗██║     ██║██╔══██╗██╔════╝██╔════╝██╔════╝
#    ███████║██║     ██║███████║╚█████╗ █████╗  ╚█████╗
#    ██╔══██║██║     ██║██╔══██║ ╚═══██╗██╔══╝   ╚═══██╗
# ██╗██║  ██║███████╗██║██║  ██║██████╔╝███████╗██████╔╝
# ╚═╝╚═╝  ╚═╝╚══════╝╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═════╝

# uncategorized
alias as='as-user'

# === System control
# sudo not required for some system commands
for cmd in mount umount shutdown poweroff reboot ; do
	alias $cmd="sudo $cmd"
done; unset cmd
alias sys='systemctl --user'
alias Sys='sudo systemctl'
alias status='systemctl --user status'
alias Status='systemctl status'
alias sys-reload='sudo systemctl daemon-reload'
alias journal='sudo journalctl -u'

# === Tmux
alias attach='tmux attach -t'
alias ts="tmux ls"

# === file management =======================
alias fm=thunar

alias -- -r='chmod -r'
alias -- +r='chmod +r'
alias -- -w='chmod -w'
alias -- +w='chmod +w'
alias -- -x='chmod -x'
alias -- +x='chmod +x'

has bat && alias cat='bat'
alias compress='tar -czvf'
alias extract='tar -xzvf'
alias tarlist='tar -tzvf'
alias zip='zip -v'
alias rm='rm -vi'
has rsync && alias cp="rsync -avhP" || alias cp='cp -vi'
alias mv='mv -vi'
alias mkdir='mkdir -v'
alias rmdir='rmdir -v'
alias chmod='chmod -v'
alias grep='grep --color=auto'

# === Git
alias stage='git add'
alias clone='git clone'
alias commit="git commit -v"
alias push="git push"
alias pull="git pull"

# === AI
alias gemini='aichat -m gemini'

# === Docker
# Add user to docker group!
alias d='docker'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"' #\t{{.Image}}"'
alias dup='docker compose up --remove-orphans'
alias ddn='docker compose down --remove-orphans'
alias dwatch='docker logs -f'

## === navigation
has zoxide && alias cd='z'
# ALTERNATIVE syntax: a cd='z' if has zoxide
# a x=y if <CONDITION>
alias ..='cd ..'
alias .-='cd -'
alias cdi='cd "$(gum file -a --height=20 --directory)"'
eza_core="--header --long --icons --group-directories-first --time-style=relative --sort Name --ignore-glob='lost+found'"
eza_git="$eza_core --git --git-repos"
alias l="eza"
alias ls="eza $eza_core --smart-group --no-filesize"
alias ll="eza $eza_git --group --no-filesize"    # full view
alias lls='ll --total-size'                      # + sizes (slower)
alias ld="eza $eza_git --only-dirs  --all --smart-group --no-filesize"  # dirs only
alias lf="eza $eza_git --only-files --all --smart-group --total-size"   # files only
# navigation ========================================================

## network manager (nmcli)
alias wifi='nmcli dev wifi'
alias connect='nmcli --ask device wifi connect'

## common typos
alias gti='git'
alias sl='ls'
alias xh=hx
## common typos

###################################################################################################################################

# 
# if [ $(command -v logo-ls) ]; then
#     alias lls="logo-ls"
#     alias lla="logo-ls -l --all"
# fi
# 
# if [ $(command -v ripgrep) ]; then
#     alias grep="ripgrep"
# fi
# 
# if [ $(command -v go-mtpfs) ]; then
#     alias mount-phone="go-mtpfs $HOME/Phone &>/dev/null & disown"
# fi
# 
# if [ $(command -v fusermount) ]; then
#     alias unmount-phone="fusermount -u $HOME/Phone"
# fi
# 
# if [ $(command -v udisksctl) ]; then
#     alias mount-iso="udisksctl loop-setup -r -f"
#     alias unmount-iso="udisksctl loop-delete -b"
#     alias mount-ssd="udisksctl mount -b /dev/nvme0n1p1"
#     alias unmount-ssd="udisksctl unmount -b /dev/nvme0n1p1"
# fi
# 
# 
# if [ $(command -v yt-dlp) ]; then
#     alias yta-aac="yt-dlp --extract-audio --audio-format aac "
#     alias yta-best="yt-dlp --extract-audio --audio-format best "
#     alias yta-flac="yt-dlp --extract-audio --audio-format flac "
#     alias yta-m4a="yt-dlp --extract-audio --audio-format m4a "
#     alias yta-mp3="yt-dlp --extract-audio --audio-format mp3 "
#     alias yta-opus="yt-dlp --extract-audio --audio-format opus "
#     alias yta-vorbis="yt-dlp --extract-audio --audio-format vorbis "
#     alias yta-wav="yt-dlp --extract-audio --audio-format wav "
#     alias ytv-best="yt-dlp -f bestvideo+bestaudio "
# fi
# 
# if [ $(command -v duf) ]; then
#     alias df='duf'
# else
#     alias df='df -h'
# fi
# alias tsm='transmission-cli -D -u 10 -w ~/Downloads/torrents'
# alias zth='zathura'
# alias f="clr && fzf"
# alias music="youtube-viewer"
# alias anime="ani-cli"
# alias flix="notflix"
# alias dmenu='dmenu -i -l 10 -fn "Iosevka Nerd Font" -p "Select File: " -nb "#282a36" -nf "#f8f8f2" -sf "#44475a" -sb "#bd93f9" '
# alias s='startx'
# alias t='bpytop'
# alias tty='tty-clock -C6 -c -t'
# alias weather='clrscr && curl -s wttr.in/gwalior | head -n $(($(curl -s wttr.in/gwalior | wc -l)  - 2)) | tail -n $(($(curl -s wttr.in/gwalior | wc -l)  - 4))'
# alias killl='killall -q'
# alias wal='feh --bg-fill -z'
# alias lock='xscreensaver-command -lock'
# alias tmux="TERM=screen-256color-bce tmux"
# alias cat='bat'
# alias nano='nano -00x'
# alias du='ncdu -x --color off'
# alias ncmpcpp='ncmpcpp ncmpcpp_directory=$HOME/.config/ncmpcpp/'
# alias spotify='spt'
# alias mocp='mocp -M "$XDG_CONFIG_HOME"/moc -O MOCDir="$XDG_CONFIG_HOME"/moc'
# alias tos="~/thinkorswim/thinkorswim"
# alias most='du -hsx * | sort -rh | head -10'
# alias wget="wget -c"
# alias tips='lbrynet txo spend --type=support --is_not_my_input --blocking'
# alias calc='bc -l'
# alias bt='bluetoothctl'
# alias jctl="journalctl -p 3 -xb"
# alias grep='grep --color=auto'
# alias fgrep='fgrep --color=auto'
# alias egrep='egrep --color=auto'
# alias edex='cd ~/.dotfiles/apps && ./edex.AppImage'
# alias retro='cd ~/.dotfiles/apps && ./retro.AppImage'
# 
# alias free='free -m'
# alias psmem='ps auxf | sort -nr -k 4'
# alias psmem10='ps auxf | sort -nr -k 4 | head -10'
# alias pscpu='ps auxf | sort -nr -k 3'
# alias pscpu10='ps auxf | sort -nr -k 3 | head -10'
# alias paux='ps aux | grep'
# 
# alias copy='xsel --clipboard --input'
# alias paste='xsel --clipboard --output'
# alias xclip='xclip -selection clipboard'
# 
# alias tb="nc termbin.com 9999"
# alias gpg-check="gpg2 --keyserver-options auto-key-retrieve --verify"
# alias gpg-retrieve="gpg2 --keyserver-options auto-key-retrieve --receive-keys"
# 
# alias ddate='date +"%R - %a, %B %d, %Y" | xclip -select clipboard && date +"%R - %a, %B %d, %Y"'
# alias dday='date +"%Y.%m.%d - " | xclip -select clipboard ; date +"%Y.%m.%d"'
# alias week='date +%V'
# alias ping='ping -c 5'
# alias fastping='ping -c 100 -s .2'
# alias rec='gpg --recv-keys --keyserver hkp://pgp.mit.edu'

## Additional Aliases
# alias ip='curl ipinfo.io/ip'
# alias :q='exit'
# alias please='sudo $(fc -ln -1)'
# alias pip-update='sudo pip3 list --outdated | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip3 install -U'
# 
# alias npm-update='sudo npm install npm@latest -g'
# 
# 
# alias kev="xev -event keyboard"
# 
# alias cclock="watch -t -n1 'date +%T | figlet' | lolcat"
# alias tty-clock="tty-clock -S -c -C4 -D -s -n"
# alias ccbonsai="cbonsai -ilt 0.02 -c '  ,  ,  ,  ,  ' -L 5"
# alias fzi="$HOME/.fzfimg.sh"
# alias fzr="fzf --layout=reverse --prompt ' ' --pointer '=>' --preview='less {}' --bind shift-up:preview-page-up,shift-down:preview-page-down"
# 
# alias yt="ytfzf -t"
# alias startx='startx -- -keeptty >~/.xorg.log 2>&1'
# 
# alias ....='cd ../../../'
# alias .....='cd ../../../../'
# alias ......='cd ../../../../../'
# alias .1='cd -1'
# alias .2='cd -2'
# alias .3='cd -3'
# alias .4='cd -4'
# alias .5='cd -5'
# alias .6='cd -6'
# alias .7='cd -7'
# alias .8='cd -8'
# alias .9='cd -9'
# alias _='sudo'
# alias afind='ack -il' 
# 
# alias ldot='ls -ld .*'
# alias lS='ls -1FSsh'
# alias lart='ls -1Fcart'
# alias lrt='ls -1Fcrt'
# 
# alias grepin='grep -i'
# alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS} '
# 
# # Command line shortcuts
# alias -g H='| head'
# alias -g T='| tail'
# alias -g G='| grep'
# alias -g S='| sed'
# alias -g L="| less"
# alias -g M="| most"
# alias -g LL="2>&1 | less"
# alias -g CA="2>&1 | bat -A"
# alias -g NE="2> /dev/null"
# alias -g NUL="> /dev/null 2>&1"
# alias -g P="2>&1| pygmentize -l pytb"
# 
# alias dud='du -d 1 -h'
# alias ff='find . -type f -name'
# 
# alias h='history'
# alias hgrep="fc -El 0 | grep"
# alias help='man'
# alias p='ps -f'
# alias sorter='sort -n -r'
# alias unexport='unset'
# 
# alias -s pdf=zathura
# alias -s ps=gv
# alias -s dvi=xdvi
# alias -s chm=xchm
# alias -s djvu=djview
# 
# alias -s zip="unzip -l"
# alias -s rar="unrar l"
# alias -s tar="tar tf"
# alias -s tar.gz="echo "
# alias -s ace="unace l" 
