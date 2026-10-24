#!/usr/bin/env bash
# arch-m720q — Full installer: Arch Linux + illogical-impulse + end4-pC untuk ThinkCentre M720q
# Dibuat: 2026-09-30
# Repo end4-pC: https://github.com/pctrade/end4-pC
#
# ╔════════════════════════════════════════════════════════════╗
# ║  MODE 1 — USB INSTALLER (dijalankan dari Arch ISO live) ║
# ║  MODE 2 — POST-INSTALL (dijalankan dari Arch yg sudah   ║
# ║           terinstall, untuk pasang ii + end4-pC)         ║
# ╚════════════════════════════════════════════════════════════╝
#
# CARA PAKAI:
#  1. Dari HP:  scp arch-m720q/install.sh user@archiso:~/  atau taruh di USB
#  2. Di M720q (boot dari USB Arch ISO):  bash install.sh
#
set -euo pipefail

REPO_END4PC="https://github.com/pctrade/end4-pC.git"
REPO_II="https://github.com/end-4/dots-hyprland.git"
QS_DIR=".config/quickshell"

info(){ echo -e "\033[1;36m[INFO]\033[0m $*"; }
ok(){   echo -e "\033[1;32m[ OK ]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){  echo -e "\033[1;31m[ERR ]\033[0m $*"; }

detect_mode(){
  if [ -f /etc/os-release ]; then . /etc/os-release; fi
  # kalau ada archiso Di live, atau belum ada user home yg proper
  if grep -q "archiso" /proc/cmdline 2>/dev/null || [ "$(whoami)" = "root" ] && [ ! -d /home/* 2>/dev/null ]; then
    # di live ISO?
    if [ -d /run/archiso ] || grep -q "archiso" /proc/cmdline 2>/dev/null; then echo "archiso"; else echo "postinstall"; fi
  elif command -v pacman &>/dev/null; then
    echo "postinstall"
  else
    echo "unknown"
  fi
}

MODE=$(detect_mode)

cat <<'BANNER'
╔════════════════════════════════════════════════════╗
║  ThinkCentre M720q — Arch + ii + end4-pC Setup   ║
║  https://github.com/pctrade/end4-pC              ║
╚════════════════════════════════════════════════════╝
BANNER
echo "Mode terdeteksi: $MODE"
echo "Host: $(hostname 2>/dev/null || echo unknown)  User: $(whoami)  Date: $(date)"
echo ""

choose(){
  echo ""
  echo "  Pilih mau ngapain:"
  echo "    1) FULL — Install Arch Linux ke disk + ii + end4-pC  (dari Arch ISO live USB)"
  echo "    2) DESKTOP ONLY — Arch sudah terinstall, pasang hyprland + ii + end4-pC"
  echo "    3) SHELL ONLY — Arch + hyprland sudah ada, pasang end4-pC doang (paling cepat)"
  echo "    q) Keluar"
  echo ""
  read -p "Pilihan [1/2/3/q]: " pil
  echo "$pil"
}

# ── MODE 3: shell only (paling simpel, jalan di Arch yg udah ada hyprland) ──
do_shell_only(){
  echo ""
  info "SHELL ONLY — pasang end4-pC"
  if ! command -v pacman &>/dev/null; then err "pacman tidak ada, bukan Arch?"; return 1; fi
  TARGET="$HOME/$QS_DIR/end4-pC"
  if [ ! -d "$HOME/.config/illogical-impulse" ] && [ ! -d "$HOME/.config/quickshell/ii" ]; then
    warn "illogical-impulse belum ada — akan clone dots-hyprland & jalankan setup install"
    TMP=$(mktemp -d)
    git clone --depth 1 "$REPO_II" "$TMP/dots" 2>&1 | tail -3
    info "Jalankan: cd $TMP/dots && ./setup install"
    read -p "Lanjut install ii sekarang? [Y/n]: " a; [[ "$a" =~ ^[Nn] ]] || bash "$TMP/dots/setup" install
  else ok "illogical-impulse ada ✓"; fi
  mkdir -p "$HOME/$QS_DIR"
  if [ -d "$TARGET/.git" ]; then info "Update end4-pC..."; git -C "$TARGET" pull --ff-only || git -C "$TARGET" fetch origin && git -C "$TARGET" reset --hard origin/main
  else git clone "$REPO_END4PC" "$TARGET"; fi
  ok "end4-pC di $TARGET ✓"
  info "Jalankan shell:"
  echo "  killall qs 2>/dev/null; qs -c end4-pC > /dev/null 2>&1 & disown"
  read -p "Jalankan sekarang? [Y/n]: " a
  if [[ ! "$a" =~ ^[Nn] ]]; then
    killall qs 2>/dev/null || killall quickshell 2>/dev/null || true; sleep 1
    if command -v qs &>/dev/null; then qs -c end4-pC > /dev/null 2>&1 & disown; else quickshell -c end4-pC > /dev/null 2>&1 & disown; fi
    sleep 2; pgrep -a quickshell 2>/dev/null | head -3; pgrep -a qs 2>/dev/null | head -3; ok "Done"
  fi
  echo ""
  read -p "Jadikan default (edit hyprland/variables.lua qsConfig=end4-pC)? [y/N]: " a
  if [[ "$a" =~ ^[Yy] ]]; then
    F="$HOME/.config/hypr/hyprland/variables.lua"; [ -f "$F" ] && cp "$F" "$F.bak.$(date +%s)" && sed -i 's/hl\.env("qsConfig", *"[^"]*")/hl.env("qsConfig", "end4-pC")/' "$F" && ok "Default = end4-pC. hyprctl reload untuk apply."
  fi
}

# ── MODE 2: desktop only (Arch sudah ada, belum ada hyprland/ii) ──
do_desktop_only(){
  echo ""
  info "DESKTOP ONLY — pasang deps Hyprland + ii + end4-pC"
  if ! command -v pacman &>/dev/null; then err "Bukan Arch"; return 1; fi
  info "1/3 Install yay (AUR helper) kalau belum ada..."
  if ! command -v yay &>/dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git
    rm -rf /tmp/buildyay; git clone https://aur.archlinux.org/yay-bin.git /tmp/buildyay
    (cd /tmp/buildyay && makepkg -si --noconfirm); rm -rf /tmp/buildyay; ok "yay terinstall"
  else ok "yay sudah ada"; fi
  info "2/3 Clone dots-hyprland & install (ini lama, bisa 30-60 menit di M720q)..."
  TMP=$(mktemp -d)
  git clone --depth 1 "$REPO_II" "$TMP/dots"
  echo "  Akan jalankan: $TMP/dots/setup install  (butuh sudo, akan update pacman -Syu & build banyak paket)"
  read -p "Lanjut? [Y/n]: " a
  if [[ ! "$a" =~ ^[Nn] ]]; then bash "$TMP/dots/setup" install; ok "ii selesai"; else warn "Skip ii"; fi
  info "3/3 Pasang end4-pC..."
  do_shell_only
}

# ── MODE 1: full Arch install ──
do_full_arch(){
  echo ""
  cat <<'WARN'

  ╔════════════════════════════════════════════════════════════╗
  ║  FULL ARCH INSTALL — AKAN HAPUS DATA DI DISK TARGET!    ║
  ║  Backup dulu kalau ada data penting.                     ║
  ╚════════════════════════════════════════════════════════════╝
WARN
  if [ "$(whoami)" != "root" ]; then err "Harus jalan sebagai root di Arch ISO (user root live)"; echo "  boot dari USB Arch ISO, login root, lalu bash install.sh"; return 1; fi
  echo ""
  lsblk -d -o NAME,SIZE,MODEL | head -20
  echo ""
  lsblk -f 2>&1 | head -30
  echo ""
  # deteksi disk M720q (NVMe biasa /dev/nvme0n1 atau SATA /dev/sda)
  warn "M720q biasanya pakai NVMe (nvme0n1) atau SATA SSD (sda)."
  read -p "Masukkan disk target (contoh: /dev/nvme0n1 atau /dev/sda): " DISK
  [ -b "$DISK" ] || { err "Disk $DISK tidak ada"; return 1; }
  echo "Disk: $DISK"
  lsblk "$DISK" 2>&1 | head -20
  echo ""
  read -p "Ketik YA untuk lanjut hapus & install Arch ke $DISK : " confirm
  [ "$confirm" = "YA" ] || { warn "Batal"; return 1; }

  read -p "Hostname [m720q]: " HOSTN; HOSTN=${HOSTN:-m720q}
  read -p "Username [pctrade]: " USERNAME; USERNAME=${USERNAME:-pctrade}
  read -s -p "Password untuk $USERNAME (dan root): " PASS; echo ""
  read -p "Timezone [Asia/Jakarta]: " TZ; TZ=${TZ:-Asia/Jakarta}
  read -p "Locale [en_US.UTF-8]: " LOCALE; LOCALE=${LOCALE:-en_US.UTF-8}
  # M720q Tiny: Intel UHD 630, wifi Intel, ethernet Intel
  # UEFI only (Tiny tidak ada legacy)
  echo ""
  info "Konfigurasi: HOST=$HOSTN USER=$USERNAME DISK=$DISK TZ=$TZ LOCALE=$LOCALE"
  read -p "Lanjut? [Y/n]: " a; [[ "$a" =~ ^[Nn] ]] && return 1

  info "Sync clock & update mirror..."
  timedatectl set-ntp true 2>/dev/null || true
  pacman -Sy --noconfirm 2>&1 | tail -5

  info "Partisi $DISK (GPT UEFI: EFI 1GB + root sisanya + swap 8GB)..."
  # pakai sgdisk / parted
  if command -v sgdisk &>/dev/null; then
    sgdisk --zap-all "$DISK" 2>&1 | tail -3
    sgdisk -o "$DISK"
    sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"
    sgdisk -n 2:0:-8G -t 2:8300 -c 2:"ROOT" "$DISK"
    sgdisk -n 3:0:0 -t 3:8200 -c 3:"SWAP" "$DISK"
  else
    parted -s "$DISK" mklabel gpt mkpart EFI fat32 1MiB 1025MiB set 1 esp on mkpart ROOT ext4 1025MiB 100% 2>&1 | tail -5
    # fallback manual, swap belakangan
  fi
  partprobe "$DISK" 2>/dev/null; sleep 2; lsblk "$DISK" 2>&1 | head -20

  # tentukan partisi
  if [[ "$DISK" == *"nvme"* ]]; then P1="${DISK}p1"; P2="${DISK}p2"; P3="${DISK}p3"; else P1="${DISK}1"; P2="${DISK}2"; P3="${DISK}3"; fi
  info "Partisi: EFI=$P1 ROOT=$P2 SWAP=$P3"

  info "Format..."
  mkfs.fat -F32 "$P1" 2>&1 | tail -3
  mkfs.ext4 -F "$P2" 2>&1 | tail -3
  mkswap "$P3" 2>&1 | tail -3; swapon "$P3" 2>&1 | tail -1

  info "Mount..."
  mount "$P2" /mnt
  mkdir -p /mnt/boot
  mount "$P1" /mnt/boot

  info "Pacstrap base system (ini agak lama)..."
  # M720q: Intel i5-8400T/i5-8500T, UHD 630, butuh intel-ucode, iwd/networkmanager
  pacstrap /mnt base base-devel linux linux-firmware intel-ucode \
    networkmanager iwd sudo vim git curl wget efibootmgr \
    grub os-prober 2>&1 | tail -20

  info "fstab..."
  genfstab -U /mnt >> /mnt/etc/fstab; cat /mnt/etc/fstab | tail -10

  info "Chroot setup..."
  arch-chroot /mnt /bin/bash <<CHROOT
set -e
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
hwclock --systohc 2>/dev/null || true
echo "$LOCALE UTF-8" >> /etc/locale.gen
echo "id_ID.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen 2>&1 | tail -5
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "$HOSTN" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTN
HOSTS
echo "root:$PASS" | chpasswd
useradd -m -G wheel,video,audio,storage,power,network -s /bin/bash $USERNAME
echo "$USERNAME:$PASS" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
# sudo tanpa password untuk wheel (biar setup ii lancar) — nanti bisa di-ketat-in
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers 2>/dev/null || echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

systemctl enable NetworkManager 2>&1 | tail -2
systemctl enable iwd 2>&1 | tail -2 || true

# grub UEFI
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 2>&1 | tail -5
grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tail -5
CHROOT
  ok "Chroot selesai"

  info "Copy post-install script ke /mnt/home/$USERNAME ..."
  mkdir -p /mnt/home/$USERNAME
  cat > /mnt/home/$USERNAME/post-install-m720q.sh <<'POST'
#!/usr/bin/env bash
set -e
REPO_II="https://github.com/end-4/dots-hyprland.git"
REPO_END4PC="https://github.com/pctrade/end4-pC.git"
echo "=== Post-install M720q: ii + end4-pC ==="
echo "User: $(whoami)  PWD: $PWD"
# yay dulu
if ! command -v yay &>/dev/null; then
  echo "[1/3] Install yay..."
  rm -rf /tmp/buildyay; git clone https://aur.archlinux.org/yay-bin.git /tmp/buildyay
  (cd /tmp/buildyay && makepkg -si --noconfirm); rm -rf /tmp/buildyay
fi
echo "[2/3] Install dots-hyprland (ii) — ini lama..."
TMP=$(mktemp -d); git clone --depth 1 "$REPO_II" "$TMP/dots"
bash "$TMP/dots/setup" install
echo "[3/3] Install end4-pC..."
mkdir -p ~/.config/quickshell
if [ -d ~/.config/quickshell/end4-pC/.git ]; then git -C ~/.config/quickshell/end4-pC pull --ff-only; else git clone "$REPO_END4PC" ~/.config/quickshell/end4-pC; fi
# set default qsConfig
F="$HOME/.config/hypr/hyprland/variables.lua"
if [ -f "$F" ]; then cp "$F" "$F.bak.$(date +%s)"; sed -i 's/hl\.env("qsConfig", *"[^"]*")/hl.env("qsConfig", "end4-pC")/' "$F"; echo "Default qsConfig -> end4-pC"; fi
echo "=== Selesai! Reboot & login Hyprland ==="
echo "  Manual run: killall qs 2>/dev/null; qs -c end4-pC > /dev/null 2>&1 & disown"
POST
  chmod +x /mnt/home/$USERNAME/post-install-m720q.sh
  arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/post-install-m720q.sh"

  echo ""
  ok "Arch terinstall ke $DISK ✓"
  echo ""
  echo "  NEXT STEPS:"
  echo "    1) umount -R /mnt && reboot  (cabut USB)"
  echo "    2) login sebagai $USERNAME"
  echo "    3) bash ~/post-install-m720q.sh   (lanjut pasang Hyprland + ii + end4-pC, 30-60 menit)"
  echo ""
  read -p "Reboot sekarang? [y/N]: " a
  if [[ "$a" =~ ^[Yy] ]]; then umount -R /mnt; swapoff "$P3" 2>/dev/null || true; reboot; fi
}

# ── main ──
if [ "$MODE" = "archiso" ]; then
  echo "Terdeteksi boot dari Arch ISO live — tawarkan FULL install"
  pil=$(choose)
else
  # sudah di Arch terinstall (atau bukan Arch)
  if command -v pacman &>/dev/null; then
    echo "Terdeteksi Arch terinstall — mode DESKTOP/SHELL"
    pil=$(choose)
  else
    echo "Bukan Arch / pacman tidak ada. Pilihan terbatas."
    pil=$(choose)
  fi
fi
case "$pil" in
  1) do_full_arch ;;
  2) do_desktop_only ;;
  3) do_shell_only ;;
  q|Q) echo "Bye"; exit 0 ;;
  *) echo "Pilihan tidak valid"; exit 1 ;;
esac
