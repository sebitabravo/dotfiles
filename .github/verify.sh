#!/usr/bin/env bash
# macOS — auditoria read-only de config/macos/defaults.sh
#
# No escribe nada. Compara el estado real de la maquina contra lo que
# defaults.sh promete y reporta drift. Reemplaza el conteo hardcodeado que
# el README tenia antes ("263 defaults write, 54 secciones"): ese numero se
# desincroniza en cuanto se toca defaults.sh, esto no.
#
# Exit 0: todo en orden. Exit 1: hay drift para revisar.
# Apply:  chmod +x verify.sh && ./verify.sh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
DEFAULTS_SH="$ROOT/config/macos/defaults.sh"
DRIFT=0

ok() { echo "[OK] $1"; }
warn() {
  echo "[WARN] $1"
  DRIFT=$((DRIFT + 1))
}
skip() { echo "[SKIP] $1"; }
info() { echo "[INFO] $1"; }

echo "=== macOS $(sw_vers -productVersion) ($(uname -m)) ==="

# ── Conteo real del script (defecto: numero hardcodeado en el README) ──
if [ -f "$DEFAULTS_SH" ]; then
  WRITE_COUNT="$(grep -c '^  *defaults write ' "$DEFAULTS_SH" || true)"
  DELETE_COUNT="$(grep -c '^  *defaults delete\|delete_default ' "$DEFAULTS_SH" || true)"
  info "defaults.sh: $WRITE_COUNT 'defaults write', $DELETE_COUNT 'defaults delete'"
else
  warn "defaults.sh no encontrado junto a verify.sh"
fi

echo "--- Tier 2: controles de seguridad (solo lectura) ---"

if fdesetup status 2>/dev/null | grep -q "FileVault is On"; then
  ok "FileVault On"
else
  warn "FileVault: revisar con 'sudo fdesetup enable'"
fi

if /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -qi enabled; then
  ok "Firewall enabled"
else
  warn "Firewall apagado"
fi

if /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | grep -qi "stealth mode is on"; then
  ok "Firewall stealth mode on"
else
  warn "Stealth mode apagado"
fi

if csrutil status 2>/dev/null | grep -qi "enabled"; then
  ok "SIP enabled"
else
  warn "SIP disabled (decision tuya, no la toca ningun script de este repo)"
fi

if spctl --status 2>/dev/null | grep -qi "assessments enabled"; then
  ok "Gatekeeper enabled"
else
  warn "Gatekeeper: revisar con 'spctl --status'"
fi

if [ -f /etc/pam.d/sudo_local ]; then
  ok "Touch ID para sudo configurado (sudo_local)"
else
  skip "Touch ID para sudo no configurado (opcional, requiere macOS 14+)"
fi

if [ "$(stat -f '%Sf' /Volumes)" = "-" ]; then
  ok "/Volumes visible en Finder"
else
  warn "/Volumes oculto: sudo chflags nohidden /Volumes"
fi

if DevToolsSecurity -status 2>/dev/null | grep -qi "enabled"; then
  ok "Developer mode (DevToolsSecurity) habilitado"
else
  warn "Developer mode deshabilitado: sudo DevToolsSecurity -enable"
fi

if pmset -g custom 2>/dev/null | grep -Eq "powernap[[:space:]]+1"; then
  warn "Power Nap activo: sudo pmset -a powernap 0"
else
  ok "Power Nap desactivado"
fi

if pmset -g custom 2>/dev/null | grep -Eq "womp[[:space:]]+0"; then
  ok "Wake for network access desactivado (womp=0)"
else
  warn "Wake for network access activo: sudo pmset -a womp 0 proximitywake 1"
fi

if pmset -g cap 2>/dev/null | grep -qi proximitywake; then
  if pmset -g custom 2>/dev/null | grep -Eq "proximitywake[[:space:]]+1"; then
    ok "Wake by proximity activado"
  else
    warn "Wake by proximity desactivado: sudo pmset -a womp 0 proximitywake 1"
  fi
else
  skip "Wake by proximity no expuesto por este hardware (pmset -g cap)"
fi

# autorestart es de los settings que pmset -g solo muestra en "Currently in
# use" cuando la maquina esta en AC (documentado, igual que womp). Verificado
# con el cargador puesto en este M3 Air: `pmset -g cap` no lista "autorestart"
# entre las capacidades soportadas por este hardware (a diferencia de un iMac,
# donde si aparece) — el mismo comportamiento no-op que askForPassword en
# screensaver: sudo pmset -a autorestart 1 devuelve exito pero no hace nada
# verificable. No se reporta como drift: pedirte "corre este comando" cuando
# la evidencia dice que no cambia nada seria mentir.
if pmset -g cap 2>/dev/null | grep -qi autorestart; then
  if pmset -g 2>/dev/null | grep -Eq "^ autorestart[[:space:]]+1$"; then
    ok "Auto-restart en freeze/corte de luz configurado"
  else
    warn "Auto-restart sin configurar: sudo pmset -a autorestart 1"
  fi
else
  skip "Auto-restart: pmset -g cap no lo lista como capacidad de este hardware (probable no-op, como askForPassword)"
fi

echo "--- Verificaciones que piden sudo (se salta si no se puede) ---"
if sudo -n true 2>/dev/null; then
  if sudo sysadminctl -secureTokenStatus "$(id -un)" 2>&1 | grep -qi "ENABLED"; then
    ok "Secure Token enabled"
  else
    warn "Secure Token: revisar con 'sysadminctl -secureTokenStatus'"
  fi
  if sysadminctl -screenLock status 2>&1 | grep -qi "immediate"; then
    ok "Bloqueo de pantalla inmediato"
  else
    warn "Bloqueo de pantalla: revisar en Ajustes > Pantalla bloqueada"
  fi
  if sudo defaults read /Library/Preferences/com.apple.loginwindow AdminHostInfo 2>/dev/null | grep -qx "HostName"; then
    ok "Login Window muestra HostName"
  else
    warn "Login Window sin HostName: sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName"
  fi
  if sudo systemsetup -getremotelogin 2>/dev/null | grep -qi "Off"; then
    ok "SSH remoto apagado"
  else
    warn "SSH remoto prendido (puede ser intencional si lo usas para desarrollo)"
  fi
else
  skip "sudo sin cache: correr con 'sudo -v' antes para incluir estos 4 checks"
fi

echo "--- Tier 1: keys de usuario de mayor impacto ---"

if defaults read com.apple.AdLib allowIdentifierForAdvertising 2>/dev/null | grep -q "^0$"; then
  ok "IDFA desactivado"
else
  warn "IDFA activo: defaults write com.apple.AdLib allowIdentifierForAdvertising -int 0"
fi

if defaults read NSGlobalDomain NSAppSleepDisabled >/dev/null 2>&1; then
  warn "NSAppSleepDisabled sigue escrito: defaults delete NSGlobalDomain NSAppSleepDisabled"
else
  ok "App Nap en default de Apple (key ausente)"
fi

if defaults read com.apple.dock autohide 2>/dev/null | grep -q "^1$"; then
  ok "Dock auto-hide activo"
else
  skip "Dock auto-hide no activo (preferencia, no defecto)"
fi

echo "--- Tier 3: exclusiones de indexado ---"
DEV_EXCLUDE_PATHS=(
  "$HOME/Developer"
  "$HOME/Library/Developer/Xcode/DerivedData"
  "$HOME/Library/Caches"
  "$HOME/.cache"
  "$HOME/go/pkg"
  "$HOME/Library/Containers/com.docker.docker"
)
for p in "${DEV_EXCLUDE_PATHS[@]}"; do
  if [ ! -e "$p" ]; then
    skip "$p no existe"
    continue
  fi
  if [ -f "$p/.metadata_never_index" ]; then
    ok "Spotlight excluye $p"
  else
    warn "Spotlight no excluye $p"
  fi
  if tmutil isexcluded "$p" 2>/dev/null | grep -q "\[Excluded\]"; then
    ok "Time Machine excluye $p"
  else
    warn "Time Machine no excluye $p"
  fi
done

echo "=== $DRIFT item(s) con drift ==="
if [ "$DRIFT" -gt 0 ]; then
  exit 1
fi
exit 0
