#!/usr/bin/env bash
#
# run-all-scans.sh — Lance toute la chaîne de scans "shift-left" en une fois.
# À utiliser en démonstration ou en récapitulatif de fin de journée.
#
# Les rapports sont écrits dans ./rapports/ (à la racine de la formation).
#
# Usage :  ./scripts/run-all-scans.sh   (à lancer depuis formation-devsecops/)
#
set -uo pipefail

# On se place à la racine du dépôt Juice Shop (parent de formation-devsecops/)
FORMATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$FORMATION_DIR/.." && pwd)"
OUT="$FORMATION_DIR/rapports"
mkdir -p "$OUT"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; NC='\033[0m'
step(){ echo -e "\n${BLUE}══════════════════════════════════════════════\n  $1\n══════════════════════════════════════════════${NC}"; }

cd "$REPO_ROOT"
echo "Dépôt analysé : $REPO_ROOT"
echo "Rapports      : $OUT"

step "1. SECRETS — Gitleaks"
gitleaks dir . --no-banner --redact \
  --report-format json --report-path "$OUT/gitleaks.json" || true
echo "→ Fuites trouvées : $(grep -o '"RuleID"' "$OUT/gitleaks.json" 2>/dev/null | wc -l)"

step "2. SAST — Semgrep"
semgrep scan --config p/owasp-top-ten --config p/javascript --config p/typescript \
  --exclude test --exclude data/static/codefixes --exclude frontend/src/assets \
  --metrics=off --json --output "$OUT/semgrep.json" \
  routes lib server.ts app.ts models 2>/dev/null || true
echo "→ Rapport : $OUT/semgrep.json"

step "3. SCA — Trivy (dépendances du dépôt)"
trivy fs --quiet --scanners vuln --severity CRITICAL,HIGH \
  --format json -o "$OUT/trivy-fs.json" . || true
echo "→ Rapport : $OUT/trivy-fs.json"

step "4. CONTENEUR — Trivy (image Docker)"
trivy image --quiet --scanners vuln --severity CRITICAL,HIGH \
  --format json -o "$OUT/trivy-image.json" bkimminich/juice-shop:v20.2.0 || true
echo "→ Rapport : $OUT/trivy-image.json"

step "5. IaC — Trivy config (Terraform / Docker intentionnellement vulnérables)"
trivy config --quiet --severity CRITICAL,HIGH \
  --format json -o "$OUT/trivy-iac.json" infrastructure || true
echo "→ Rapport : $OUT/trivy-iac.json"

echo -e "\n${GREEN}✔ Tous les scans sont terminés. Rapports dans : $OUT${NC}"
echo "  (Le DAST/ZAP se lance séparément — voir Lab 6 — car il attaque l'app en marche.)"
