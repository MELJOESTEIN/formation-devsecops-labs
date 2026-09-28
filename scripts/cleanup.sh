#!/usr/bin/env bash
#
# cleanup.sh — Arrête et supprime les conteneurs de la formation.
# Usage :  ./scripts/cleanup.sh
#
set -uo pipefail
GREEN='\033[0;32m'; NC='\033[0m'

echo "Nettoyage de l'environnement de formation…"

for name in juice-shop; do
  if docker ps -a --format '{{.Names}}' | grep -qx "$name"; then
    docker rm -f "$name" >/dev/null && echo "  ✔ conteneur '$name' supprimé"
  fi
done

# Le rapport ZAP tourne dans un conteneur éphémère, rien à nettoyer normalement.
echo -e "${GREEN}✔ Terminé.${NC}"
echo "  (Les images Docker sont conservées pour la prochaine session.)"
