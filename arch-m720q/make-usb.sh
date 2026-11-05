#!/usr/bin/env bash
# make-usb.sh — Builder USB Arch one-shot untuk M720q
# Dijalankan di LINUX (bukan di Termux/HP) — butuh archiso, sudo, dan internet.
# Di HP (Termux) cuma bisa bikin Ventoy-style USB, bukan ISO rebuild.
# Usage:
#   # Di PC Linux (Arch/Debian/Ubuntu):
#   bash make-usb.sh /dev/sdX   -> download ISO, inject autoinstall, flash USB
#   # Di Termux/HP (terbatas):
#   bash make-usb.sh --ventoy   -> bikin Ventoy USB + copy autoinstall
set -euo pipefail
ARCH_ISO_URL="https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"
# fallback mirrors kalau geo down
ARCH_ISO_URL2="https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"

info(){ echo -e "\033[1;36m[INFO]\033[0m $*"; }
ok(){ echo -e "\033[1;32m[ OK ]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){ echo -e "\033[1;31m[ERR ]\033[0m $*" >&2; }

need(){ command -v "$1" &>/dev/null || { err "butuh $1 — install dulu"; return 1; }; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUTO_SRC="$SCRIPT_DIR/autoinstall-unattended.sh"
CACHE_DIR="${CACHE_DIR:-$HOME/.cache/m720q-usb}"
ISO_PATH="$CACHE_DIR/archlinux-x86_64.iso"

mkdir -p "$CACHE_DIR"

if [[ "${1:-}" == "--ventoy" ]]; then
  echo "╔════════════════════════════════════════════╗"
  echo "║  M720q Ventoy USB Builder (Termux mode)   ║"
  echo "╚════════════════════════════════════════════╝"
  echo "HP nggak bisa build ISO (butuh archiso/mksquashfs)."
  echo "Ventoy mode: download ISO + taruh autoinstall di USB."
  echo ""
  if [ -f "$AUTO_SRC" ]; then echo "autoinstall: $AUTO_SRC ✓"; else err "autoinstall-unattended.sh tidak ada di $SCRIPT_DIR"; exit 1; fi
  echo ""
  echo "LANGKAH DI HP -> M720q (paling simpel, tanpa builder):"
  echo "  1. Di HP, download Arch ISO:"
  echo "     curl -L -o /sdcard/archlinux-x86_64.iso $ARCH_ISO_URL"
  echo "  2. Flash ke USB pakai EtchDroid / Ventoy (di HP kalau ada OTG) atau pakai PC:"
  echo "     - Ventoy: install Ventoy ke USB, lalu copy archlinux-x86_64.iso ke USB"
  echo "  3. Copy autoinstall ke USB (root partisi):"
  echo "     cp $AUTO_SRC /path/ke/USB/autoinstall-unattended.sh"
  echo "  4. Colok USB ke M720q, boot USB, login root (tanpa password di live), lalu:"
  echo "     bash /run/archiso/bootmnt/autoinstall-unattended.sh"
  echo "     # atau kalau Ventoy: bash /run/archiso/bootmnt/../autoinstall-unattended.sh"
  echo ""
  echo "  Alternatif TANPA USB (kalau M720q ada internet + Arch live via PXE/netboot):"
  echo "     curl -fsSL https://raw.githubusercontent.com/pctrade/end4-pC/main/arch-m720q/autoinstall-unattended.sh | bash"
  echo ""
  exit 0
fi

# ── Full ISO rebuild mode (butuh Linux x86_64 + archiso) ──
if [ $# -lt 1 ]; then
  echo "Usage:"
  echo "  bash make-usb.sh /dev/sdX          # flash USB (butuh sudo + archiso)"
  echo "  bash make-usb.sh --ventoy          # petunjuk Ventoy (bisa di Termux)"
  echo "  bash make-usb.sh --iso-only        # cuma download + patch ISO, tidak flash"
  exit 1
fi

if [[ "$1" == "--iso-only" ]]; then
  ISO_ONLY=true; USB_DEV=""
else
  ISO_ONLY=false; USB_DEV="$1"
  [[ -b "$USB_DEV" ]] || { err "$USB_DEV bukan block device"; lsblk -d -o NAME,SIZE,MODEL 2>&1 | head -20; exit 1; }
fi

# cek tools
if ! command -v mkarchiso &>/dev/null; then
  warn "mkarchiso tidak ada"
  echo "  Arch:      sudo pacman -S archiso"
  echo "  Debian/Ubuntu: tidak ada paket archiso — pakai Ventoy mode aja: bash make-usb.sh --ventoy"
  exit 1
fi
need xorriso; need mksquashfs; need wget || need curl

info "Download Arch ISO kalau belum ada..."
if [ -f "$ISO_PATH" ]; then ok "Cache ada: $ISO_PATH ($(du -h "$ISO_PATH" | cut -f1))"; else
  info "Download $ARCH_ISO_URL ..."
  if command -v wget &>/dev/null; then wget -O "$ISO_PATH" "$ARCH_ISO_URL" || wget -O "$ISO_PATH" "$ARCH_ISO_URL2"
  else curl -L -o "$ISO_PATH" "$ARCH_ISO_URL" || curl -L -o "$ISO_PATH" "$ARCH_ISO_URL2"; fi
  ok "Download selesai: $(du -h "$ISO_PATH" | cut -f1)"
fi

info "Patch ISO: inject autoinstall-unattended.sh + install.sh..."
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
mkdir -p "$WORKDIR/iso"
# extract ISO
info "Extract ISO..."
xorriso -osirrox on -indev "$ISO_PATH" -cpx / "$WORKDIR/iso" -- 2>&1 | tail -5
# inject scripts ke root ISO
cp "$AUTO_SRC" "$WORKDIR/iso/autoinstall-unattended.sh"
cp "$SCRIPT_DIR/install.sh" "$WORKDIR/iso/install.sh" 2>/dev/null || true
chmod +x "$WORKDIR/iso/"*.sh
echo "Injected: $(ls -lh "$WORKDIR/iso/"*.sh 2>&1 | head -5)"

OUT_ISO="$CACHE_DIR/m720q-arch-$(date +%Y%m%d).iso"
info "Rebuild ISO -> $OUT_ISO (butuh xorriso)..."
# quick rebuild: pakai xorriso mkisofs (lebih sederhana daripada mkarchiso releng lengkap)
# Untuk one-shot simpel, cukup tambahin file ke ISO existing tanpa rebuild squashfs
xorriso -as mkisofs -o "$OUT_ISO" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -isohybrid-mbr "$WORKDIR/iso/../" 2>&1 | tail -10 || \
xorriso -as mkisofs -o "$OUT_ISO" "$WORKDIR/iso" 2>&1 | tail -10
ok "ISO patched: $OUT_ISO ($(du -h "$OUT_ISO" | cut -f1))"

if [[ "$ISO_ONLY" == "true" ]]; then
  echo "ISO siap: $OUT_ISO"
  echo "Flash manual: dd if=$OUT_ISO of=/dev/sdX bs=4M status=progress && sync"
  exit 0
fi

echo ""
warn "Akan flash $OUT_ISO ke $USB_DEV — SEMUA DATA DI $USB_DEV AKAN HILANG!"
lsblk "$USB_DEV" 2>&1 | head -10
read -p "Ketik YA untuk lanjut flash: " c; [[ "$c" == "YA" ]] || { warn "Batal"; exit 1; }
info "Flash..."
sudo dd if="$OUT_ISO" of="$USB_DEV" bs=4M status=progress conv=fsync 2>&1 | tail -5
sync
ok "USB siap! Colok ke M720q -> boot USB -> login root -> bash /run/archiso/bootmnt/autoinstall-unattended.sh"
