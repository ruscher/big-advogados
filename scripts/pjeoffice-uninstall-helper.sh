#!/usr/bin/env bash
# pjeoffice-uninstall-helper.sh — Privileged removal helper for PJeOffice Pro
# Called via pkexec from the BigCertificados app
# Usage: pkexec bash /path/to/pjeoffice-uninstall-helper.sh

set -euo pipefail

INSTALL_DIR="/usr/share/pjeoffice-pro"
BIN_LINK="/usr/bin/pjeoffice-pro"
DESKTOP_FILE="/usr/share/applications/pje-office.desktop"
ICON_FILE="/usr/share/icons/hicolor/512x512/apps/pjeoffice.png"

echo "LOG: Iniciando remoção do PJeOffice Pro..."

# Remove installation directory
if [[ -d "${INSTALL_DIR}" ]]; then
    echo "LOG: Removendo ${INSTALL_DIR}..."
    rm -rf "${INSTALL_DIR}"
    echo "LOG: Diretório removido."
else
    echo "LOG: Diretório ${INSTALL_DIR} não encontrado (já removido)."
fi

# Remove binary symlink
if [[ -L "${BIN_LINK}" || -f "${BIN_LINK}" ]]; then
    echo "LOG: Removendo ${BIN_LINK}..."
    rm -f "${BIN_LINK}"
    echo "LOG: Link simbólico removido."
else
    echo "LOG: ${BIN_LINK} não encontrado."
fi

# Remove desktop entry
if [[ -f "${DESKTOP_FILE}" ]]; then
    echo "LOG: Removendo entrada do menu..."
    rm -f "${DESKTOP_FILE}"
    echo "LOG: Entrada do menu removida."
else
    echo "LOG: Entrada do menu não encontrada."
fi

# Remove icon
if [[ -f "${ICON_FILE}" ]]; then
    echo "LOG: Removendo ícone..."
    rm -f "${ICON_FILE}"
    gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null || true
    echo "LOG: Ícone removido."
else
    echo "LOG: Ícone não encontrado."
fi

echo "OK: PJeOffice Pro removido com sucesso!"
