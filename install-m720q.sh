#!/usr/bin/env bash
# end4-pC installer untuk ThinkCentre M720q
# Repo: https://github.com/pctrade/end4-pC
# Usage di M720q:  bash install-m720q.sh   atau   curl -fsSL https://raw.githubusercontent.com/pctrade/end4-pC/main/install-m720q.sh | bash
set -e

REPO="https://github.com/pctrade/end4-pC.git"
QS_DIR="$HOME/.config/quickshell"
TARGET="$QS_DIR/end4-pC"
HYPR_VARS="$HOME/.config/hypr/hyprland/variables.lua"
II_REPO="https://github.com/end-4/dots-hyprland.git"

info(){ echo -e "\033[1;36m[INFO]\033[0m $*"; }
ok(){ echo -e "\033[1;32m[ OK ]\033[0m $*"; }
warn(){ echo -e "\033[1;33m[WARN]\033[0m $*"; }
err(){ echo -e "\033[1;31m[ERR ]\033[0m $*"; }

echo "╔════════════════════════════════════════════╗"
echo "║  end4-pC installer — ThinkCentre M720q   ║"
echo "║  https://github.com/pctrade/end4-pC      ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# 1. cek distro
if [ -f /etc/os-release ]; then . /etc/os-release; echo "OS: $PRETTY_NAME"; fi
echo "User: $USER  Home: $HOME  Host: $(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null)"
echo ""

# 2. cek illogical-impulse (wajib)
if [ ! -d "$HOME/.config/illogical-impulse" ] && [ ! -d "$QS_DIR/ii" ]; then
  warn "illogical-impulse belum terdeteksi!"
  echo "     end4-pC butuh dots-hyprland dari end-4 terinstall dulu."
  echo ""
  read -p "Mau install illogical-impulse otomatis? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy] ]]; then
    info "Cloning dots-hyprland..."
    if command -v git &>/dev/null; then
      TMP_II=$(mktemp -d)
      git clone --depth 1 "$II_REPO" "$TMP_II/dots-hyprland"
      echo ""
      echo "→ Jalankan installer dots-hyprland:"
      echo "  cd $TMP_II/dots-hyprland && ./install.sh"
      echo ""
      read -p "Jalankan sekarang? [y/N]: " ans2
      if [[ "$ans2" =~ ^[Yy] ]]; then
        bash "$TMP_II/dots-hyprland/install.sh" || warn "Install ii gagal, cek manual: https://github.com/end-4/dots-hyprland"
      else
        warn "Skip — install manual dulu sebelum lanjut end4-pC"
        exit 1
      fi
    else
      err "git belum terinstall. Install dulu: sudo pacman -S git  /  sudo apt install git"
      exit 1
    fi
  else
    echo "Install manual:"
    echo "  git clone https://github.com/end-4/dots-hyprland && cd dots-hyprland && ./install.sh"
    exit 1
  fi
else
  ok "illogical-impulse terdeteksi ✓"
fi

# 3. cek quickshell & hyprland
for cmd in quickshell hyprctl; do
  if command -v $cmd &>/dev/null; then ok "$cmd ada: $(command -v $cmd)"
  else warn "$cmd belum ada — pastikan dots-hyprland sudah di-setup dengan benar"; fi
done

# 4. install/update end4-pC
mkdir -p "$QS_DIR"
if [ -d "$TARGET/.git" ]; then
  info "Update end4-pC di $TARGET ..."
  git -C "$TARGET" pull --ff-only || { warn "pull gagal, coba reset"; git -C "$TARGET" fetch origin && git -C "$TARGET" reset --hard origin/main; }
else
  if [ -d "$TARGET" ]; then warn "$TARGET ada tapi bukan git repo — backup ke ${TARGET}.bak"; mv "$TARGET" "${TARGET}.bak.$(date +%s)"; fi
  info "Clone end4-pC ke $TARGET ..."
  git clone "$REPO" "$TARGET"
fi
ok "end4-pC siap di $TARGET"

# 5. test load quickshell (tanpa reload hyprland)
info "Test load quickshell end4-pC ..."
if command -v quickshell &>/dev/null; then
  if command -v qs &>/dev/null; then QS_CMD="qs"; else QS_CMD="quickshell"; fi
  echo "  Coba: killall $QS_CMD 2>/dev/null; $QS_CMD -c end4-pC > /dev/null 2>&1 & disown"
  read -p "Jalankan quickshell end4-pC sekarang? [Y/n]: " ans3
  if [[ ! "$ans3" =~ ^[Nn] ]]; then
    killall "$QS_CMD" 2>/dev/null || killall quickshell 2>/dev/null || true
    sleep 1
    "$QS_CMD" -c end4-pC > /dev/null 2>&1 & disown || quickshell -c end4-pC > /dev/null 2>&1 & disown || warn "Gagal start qs — coba manual: qs -c end4-pC"
    sleep 2
    if pgrep -a quickshell &>/dev/null || pgrep -a qs &>/dev/null; then ok "Quickshell end4-pC jalan ✓ — pgrep: $(pgrep -a quickshell 2>/dev/null | head -1) $(pgrep -a qs 2>/dev/null | head -1)"
    else warn "Quickshell tidak terdeteksi — cek log: journalctl --user -u quickshell atau qs -c end4-pC (foreground)"; fi
  fi
fi

# 6. set default (opsional)
echo ""
read -p "Jadikan end4-pC sebagai default shell (ganti qsConfig di $HYPR_VARS)? [y/N]: " ans4
if [[ "$ans4" =~ ^[Yy] ]]; then
  if [ -f "$HYPR_VARS" ]; then
    cp "$HYPR_VARS" "${HYPR_VARS}.bak.$(date +%s)"
    sed -i 's/hl\.env("qsConfig", *"[^"]*")/hl.env("qsConfig", "end4-pC")/' "$HYPR_VARS" || \
    sed -i 's/hl\.env.*qsConfig.*/hl.env("qsConfig", "end4-pC")/' "$HYPR_VARS"
    ok "Default diganti ke end4-pC → $HYPR_VARS (backup dibuat)"
    echo "  Jalankan: hyprctl reload  atau restart Hyprland"
  else
    warn "$HYPR_VARS tidak ditemukan — buat manual atau cek ~/.config/hypr/"
    echo '  Tambah: hl.env("qsConfig", "end4-pC")'
  fi
fi

# 7. keybind settings
echo ""
echo "Tambah keybind Settings (SUPER+Escape) ke Hyprland config:"
echo '  hl.bind("SUPER + escape", hl.dsp.global("quickshell:settingsToggle"), {description = "Toggle settings"})'
read -p "Mau auto-patch ke ~/.config/hypr/hyprland/keybinds.lua (jika ada)? [y/N]: " ans5
if [[ "$ans5" =~ ^[Yy] ]]; then
  for f in "$HOME/.config/hypr/hyprland/keybinds.lua" "$HOME/.config/hypr/keybinds.conf" "$HOME/.config/hypr/hyprland.conf"; do
    if [ -f "$f" ]; then
      if grep -q "settingsToggle" "$f" 2>/dev/null; then ok "Sudah ada settingsToggle di $f"; else
        echo '' >> "$f"
        echo '-- end4-pC settings toggle' >> "$f"
        echo 'hl.bind("SUPER + escape", hl.dsp.global("quickshell:settingsToggle"), {description = "Toggle settings"})' >> "$f"
        ok "Ditambah ke $f"
      fi
      break
    fi
  done
fi

echo ""
echo "═══════════════════════════════════════════════"
ok "Selesai! end4-pC terinstall."
echo ""
echo "  Manual run:  killall qs 2>/dev/null; qs -c end4-pC > /dev/null 2>&1 & disown"
echo "  Default:     edit $HYPR_VARS → hl.env(\"qsConfig\", \"end4-pC\") && hyprctl reload"
echo "  Update:      git -C $TARGET pull"
echo "═══════════════════════════════════════════════"
