#!/usr/bin/env bash
# autoinstall-unattended.sh — ONE-SHOT Arch + ii + end4-pC untuk ThinkCentre M720q
# CARA PAKAI:
#  1. Burn Arch ISO ke USB (Rufus/balenaEtcher/dd/Ventoy)
#  2. Copy file ini ke ROOT USB (sejajar dengan папка arch/)
#  3. Colok ke M720q, boot USB, login root (auto), lalu:
#     bash /run/archiso/bootmnt/autoinstall-unattended.sh
#  ATAU kalau ISO sudah dipatch via GitHub Actions, boot aja — auto 10 detik.
#
# MODE UNATTENDED: UNATTENDED=true + isi variabel, auto tanpa tanya.
# MODE INTERAKTIF: UNATTENDED=false, nanti ditanya disk/user/pass.
set -euo pipefail

# ════════════════════════════════════════════════════════
# EDIT DI SINI kalau mau unattended manual (tanpa GH Actions)
# ════════════════════════════════════════════════════════
UNATTENDED=false
DISK="/dev/nvme0n1"   # M720q Tiny: /dev/nvme0n1 (NVMe) atau /dev/sda (SATA)
HOSTN="m720q"
USERNAME="pctrade"
PASSWORD="changeme"   # GANTI!
TIMEZONE="Asia/Jakarta"
LOCALE="en_US.UTF-8"
# ════════════════════════════════════════════════════════

REPO_II="https://github.com/end-4/dots-hyprland.git"
REPO_END4PC="https://github.com/pctrade/end4-pC.git"

# Auto-config dari GH Actions ISO (disuntik saat build)
for _conf in /root/m720q-unattended.conf ./m720q-unattended.conf /run/archiso/bootmnt/m720q-unattended.conf; do
  if [ -f "$_conf" ]; then
    echo "[INFO] Load config $_conf"
    # shellcheck source=/dev/null
    source "$_conf"
    UNATTENDED=true
    break
  fi
done

info(){ echo -e "\033[1;36m[INFO]\033[0m $*"; }
ok(){ echo -e "\033[1;32m[ OK ]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){ echo -e "\033[1;31m[ERR ]\033[0m $*" >&2; }

[[ "$(whoami)" == "root" ]] || { err "Harus root di Arch ISO live!"; exit 1; }

if [[ "$UNATTENDED" != "true" ]]; then
  echo "╔════════════════════════════════════════════╗"
  echo "║  M720q ONE-SHOT — Arch + ii + end4-pC     ║"
  echo "╚════════════════════════════════════════════╝"
  lsblk -d -o NAME,SIZE,MODEL 2>&1 | head -20
  echo ""; lsblk -f 2>&1 | head -30; echo ""
  read -p "Disk target [/dev/nvme0n1]: " d; DISK=${d:-$DISK}
  read -p "Hostname [m720q]: " h; HOSTN=${h:-$HOSTN}
  read -p "Username [pctrade]: " u; USERNAME=${u:-$USERNAME}
  read -s -p "Password [$USERNAME]: " PASSWORD; echo ""
  [[ -n "$PASSWORD" ]] || { err "Password kosong!"; exit 1; }
  read -p "Timezone [Asia/Jakarta]: " t; TIMEZONE=${t:-$TIMEZONE}
  echo ""
  echo "Akan install ke: DISK=$DISK HOST=$HOSTN USER=$USERNAME TZ=$TIMEZONE"
  lsblk "$DISK" 2>&1 | head -10 || { err "Disk $DISK tidak ada"; exit 1; }
  read -p "Ketik YA untuk HAPUS $DISK dan lanjut: " c; [[ "$c" == "YA" ]] || { warn "Batal"; exit 1; }
fi

[[ -b "$DISK" ]] || { err "Disk $DISK tidak ada — cek lsblk"; exit 1; }

if [[ "$DISK" == *"nvme"* || "$DISK" == *"mmcblk"* ]]; then P1="${DISK}p1"; P2="${DISK}p2"; P3="${DISK}p3"; else P1="${DISK}1"; P2="${DISK}2"; P3="${DISK}3"; fi
info "DISK=$DISK -> EFI=$P1 ROOT=$P2 SWAP=$P3  HOST=$HOSTN USER=$USERNAME"

info "Sync clock..."; timedatectl set-ntp true 2>/dev/null || true
info "Update pacman db..."; pacman -Sy --noconfirm 2>&1 | tail -3

info "Partisi $DISK (GPT: EFI 1G + ROOT + SWAP 8G)..."
sgdisk --zap-all "$DISK" 2>&1 | tail -2
sgdisk -o "$DISK" 2>&1 | tail -2
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK" 2>&1 | tail -2
sgdisk -n 2:0:-8G -t 2:8300 -c 2:"ROOT" "$DISK" 2>&1 | tail -2
sgdisk -n 3:0:0 -t 3:8200 -c 3:"SWAP" "$DISK" 2>&1 | tail -2
partprobe "$DISK" 2>/dev/null; sleep 3; lsblk "$DISK"

info "Format..."; mkfs.fat -F32 "$P1" 2>&1 | tail -2; mkfs.ext4 -F "$P2" 2>&1 | tail -2; mkswap "$P3" 2>&1 | tail -2; swapon "$P3"
info "Mount..."; mount "$P2" /mnt; mkdir -p /mnt/boot; mount "$P1" /mnt/boot

info "Pacstrap base (5-10 menit)..."
pacstrap /mnt base base-devel linux linux-firmware intel-ucode networkmanager iwd sudo vim git curl wget efibootmgr grub os-prober 2>&1 | tail -20

info "fstab..."; genfstab -U /mnt >> /mnt/etc/fstab

info "Chroot setup..."
arch-chroot /mnt /bin/bash <<CHROOT
set -e
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc 2>/dev/null || true
echo "$LOCALE UTF-8" >> /etc/locale.gen
echo "id_ID.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen 2>&1 | tail -3
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "$HOSTN" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTN
HOSTS
echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel,video,audio,storage,power,network -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers 2>/dev/null || echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
systemctl enable NetworkManager 2>&1 | tail -1
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 2>&1 | tail -3
grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tail -3
CHROOT
ok "Base Arch selesai"

info "Inject post-install (ii + end4-pC) ke /home/$USERNAME ..."
cat > /mnt/home/$USERNAME/post-install-m720q.sh <<'POSTIN'
#!/usr/bin/env bash
set -e
REPO_II="https://github.com/end-4/dots-hyprland.git"
REPO_END4PC="https://github.com/pctrade/end4-pC.git"
echo "╔════════════════════════════════════════════╗"
echo "║  Post-install: Hyprland + ii + end4-pC    ║"
echo "╚════════════════════════════════════════════╝"
if ! command -v yay &>/dev/null; then
  echo "[1/3] Install yay..."
  sudo pacman -S --needed --noconfirm base-devel git
  rm -rf /tmp/buildyay; git clone https://aur.archlinux.org/yay-bin.git /tmp/buildyay
  (cd /tmp/buildyay && makepkg -si --noconfirm); rm -rf /tmp/buildyay
fi
echo "[2/3] dots-hyprland (30-60 menit, sabar ya)..."
TMP=$(mktemp -d); git clone --depth 1 "$REPO_II" "$TMP/dots"
bash "$TMP/dots/setup" install
echo "[3/3] end4-pC..."
mkdir -p ~/.config/quickshell
if [ -d ~/.config/quickshell/end4-pC/.git ]; then git -C ~/.config/quickshell/end4-pC pull --ff-only; else git clone "$REPO_END4PC" ~/.config/quickshell/end4-pC; fi
F="$HOME/.config/hypr/hyprland/variables.lua"
if [ -f "$F" ]; then cp "$F" "$F.bak.$(date +%s)"; sed -i 's/hl\.env("qsConfig", *"[^"]*")/hl.env("qsConfig", "end4-pC")/' "$F"; echo "Default -> end4-pC"; fi
echo ""
echo "═══════════════════════════════════════════════"
echo " SELESAI! Reboot, login Hyprland, lalu:"
echo "   qs -c end4-pC   (atau sudah auto kalau set default)"
echo "═══════════════════════════════════════════════"
POSTIN
chmod +x /mnt/home/$USERNAME/post-install-m720q.sh
arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/post-install-m720q.sh"
cat > /mnt/home/$USERNAME/README-M720Q.txt <<READM
ThinkCentre M720q — Arch + ii + end4-pC

1. Reboot, cabut USB
2. Login sebagai $USERNAME
3. Jalankan:  bash ~/post-install-m720q.sh
   (butuh internet, 30-60 menit, akan install Hyprland + semua deps + end4-pC)
4. Reboot lagi, pilih Hyprland di login, selesai.
READM
arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/README-M720Q.txt"

ok "Inject selesai"

if [[ "$UNATTENDED" == "true" ]]; then
  info "UNATTENDED: reboot dalam 5 detik..."; sleep 5
  umount -R /mnt; swapoff "$P3" 2>/dev/null || true; reboot
else
  echo ""
  ok "Arch base terinstall ke $DISK ✓"
  echo "  Lanjut:"
  echo "    1) umount -R /mnt && reboot   (cabut USB)"
  echo "    2) login $USERNAME"
  echo "    3) bash ~/post-install-m720q.sh   (pasang Hyprland+ii+end4-pC)"
  echo ""
  read -p "Reboot sekarang? [y/N]: " a; [[ "$a" =~ ^[Yy] ]] && { umount -R /mnt; swapoff "$P3" 2>/dev/null || true; reboot; }
fi
