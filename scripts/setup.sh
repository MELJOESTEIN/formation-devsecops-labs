#!/usr/bin/env bash
#
# setup.sh — Prépare l'environnement de la formation DevSecOps
# Démarre OWASP Juice Shop dans Docker et vérifie que les outils sont présents.
#
# Usage :  ./scripts/setup.sh
#
set -euo pipefail

JUICE_IMAGE="bkimminich/juice-shop:v20.2.0"
JUICE_NAME="juice-shop"
JUICE_PORT="3000"

# Couleurs
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
err()  { echo -e "  ${RED}✗${NC} $1"; }
title(){ echo -e "\n${BLUE}▸ $1${NC}"; }

echo "=================================================="
echo "   Formation DevSecOps — Mise en place (setup)"
echo "=================================================="

# ---------------------------------------------------------------------------
title "1/3 — Vérification des outils installés"
# ---------------------------------------------------------------------------
check_tool() {
  local name="$1"; local cmd="$2"
  if command -v "$name" >/dev/null 2>&1; then
    ok "$name présent  ($($cmd 2>&1 | head -n1))"
  else
    err "$name INTROUVABLE — certains labs ne fonctionneront pas."
  fi
}
check_tool docker  "docker --version"
check_tool node    "node --version"
check_tool npm     "npm --version"
check_tool gitleaks "gitleaks version"
check_tool semgrep "semgrep --version"
check_tool trivy   "trivy --version"
check_tool git     "git --version"

# ---------------------------------------------------------------------------
title "2/3 — Démarrage de OWASP Juice Shop"
# ---------------------------------------------------------------------------
if ! docker info >/dev/null 2>&1; then
  err "Le démon Docker ne répond pas. Démarrez Docker puis relancez ce script."
  exit 1
fi

# Récupère l'image si absente
if ! docker image inspect "$JUICE_IMAGE" >/dev/null 2>&1; then
  warn "Image $JUICE_IMAGE absente — téléchargement (peut prendre 1-2 min)…"
  docker pull "$JUICE_IMAGE"
else
  ok "Image $JUICE_IMAGE déjà présente."
fi

# (Re)démarre le conteneur proprement
if docker ps -a --format '{{.Names}}' | grep -qx "$JUICE_NAME"; then
  warn "Conteneur '$JUICE_NAME' existant — on le recrée."
  docker rm -f "$JUICE_NAME" >/dev/null
fi
docker run -d --name "$JUICE_NAME" -p "${JUICE_PORT}:3000" "$JUICE_IMAGE" >/dev/null
ok "Conteneur '$JUICE_NAME' démarré."

# ---------------------------------------------------------------------------
title "3/3 — Attente du démarrage de l'application"
# ---------------------------------------------------------------------------
printf "  Patientez "
for i in $(seq 1 40); do
  if curl -fs -o /dev/null "http://localhost:${JUICE_PORT}"; then
    echo ""
    ok "Juice Shop répond sur http://localhost:${JUICE_PORT}"
    echo ""
    echo "=================================================="
    echo -e "   ${GREEN}Environnement prêt ! 🧃${NC}"
    echo "   Ouvrez :  http://localhost:${JUICE_PORT}"
    echo "=================================================="
    exit 0
  fi
  printf "."
  sleep 3
done

echo ""
err "L'application n'a pas répondu à temps. Vérifiez les logs :"
echo "     docker logs $JUICE_NAME"
exit 1
