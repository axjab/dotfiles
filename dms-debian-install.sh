# Native quickshell from Debian backports (required before dms)
echo "deb http://deb.debian.org/debian trixie-backports main" | \
  sudo tee /etc/apt/sources.list.d/trixie-backports.list
sudo apt update
sudo apt install -t trixie-backports quickshell

curl -fsSL https://download.opensuse.org/repositories/home:AvengeMedia:danklinux/Debian_13/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/danklinux.gpg
echo "deb [signed-by=/etc/apt/keyrings/danklinux.gpg] https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_13/ /" | \
  sudo tee /etc/apt/sources.list.d/danklinux.list

curl -fsSL https://download.opensuse.org/repositories/home:/AvengeMedia:/dms/Debian_13/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/avengemedia-dms.gpg
echo "deb [signed-by=/etc/apt/keyrings/avengemedia-dms.gpg] https://download.opensuse.org/repositories/home:/AvengeMedia:/dms/Debian_13/ /" | \
  sudo tee /etc/apt/sources.list.d/avengemedia-dms.list

sudo apt update
sudo apt install dms
