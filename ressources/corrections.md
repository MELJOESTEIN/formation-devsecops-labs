# ✅ Corrigés — réservé au formateur

Réponses attendues aux exercices, chiffres de référence (vérifiés sur `bkimminich/juice-shop:v20.2.0`), et points de vigilance pédagogiques.

> ⚠️ Les nombres exacts peuvent varier légèrement selon la version des outils et la mise à jour des bases de CVE. Retenez les **ordres de grandeur** et les **fichiers/lignes** cités.

---

## Chiffres de référence (pour vérifier que « ça marche »)

| Lab | Commande | Résultat attendu |
|-----|----------|------------------|
| 0 | `curl .../rest/admin/application-version` | `{"version":"20.2.0"}` ; 116 challenges dans l'API |
| 1 | `gitleaks dir .` | **~69 fuites** (54 generic-api-key, 12 jwt, 3 private-key) ; **19** avec l'allowlist de test |
| 2 | `semgrep … routes lib …` | **~9 findings**, dont 2-3 `ERROR` (SQLi login/search, eval) |
| 3 | `trivy fs .` | **~0** (pas de lockfile) → point pédagogique |
| 3 | `trivy image --pkg-types library` | **52** (44 HIGH + 8 CRITICAL) |
| 4 | `trivy image --pkg-types os` | **31** (12 LOW, 18 MEDIUM, 1 HIGH) |
| 4 | `trivy config Dockerfile` | 27 tests, **2 échecs** (DS-0001 + 1 LOW) — Dockerfile bien fait |
| 5 | `trivy config infrastructure` | **8 misconfigs** (4 CRITICAL + 4 HIGH) |
| 6 | `zap-baseline.py` | **WARN: 8, PASS: 59, FAIL: 0** ; 2 alertes Medium (CSP, Cross-Domain) |
| 7 | SQLi login | Jeton JWT **role: admin** ; hash `0192023a7bbd73250516f069df18b500` = `admin123` |

---

## Lab 0 — Score Board

- **Solution** : `http://localhost:3000/#/score-board`.
- **Point clé** : c'est de l'**énumération d'URL**. On raisonne comme un attaquant : les pages ont des noms logiques.

---

## Lab 1 — Secrets

- **La plus grave** : clé privée RSA dans `lib/insecurity.ts:21` (et `terraform/networking.tf`). Elle **signe les JWT** → compromission totale (voir Lab 7 §7.5).
- **Vrais vs faux positifs** :
  - `lib/insecurity.ts`, `terraform/networking.tf` → **vrais positifs** (code applicatif / IaC).
  - `test/api/*.test.ts` → **majoritairement faux positifs** (identifiants de test), MAIS à vérifier au cas par cas.
- **Message** : le scanner propose, l'humain décide. L'allowlist réduit le bruit (69 → 19) mais ne doit jamais masquer une vraie faille.

---

## Lab 2 — SAST

- **Findings `ERROR`** : `login.ts:34` (SQLi), `search.ts:23` (SQLi), `userProfile.ts:65` (`eval` → injection de code).
- **Exercice §2.7** :
  - **Option A (`userProfile.ts:65`)** : `eval(code)` exécute une entrée utilisateur comme du JS → **RCE/SSTI**. Correction : supprimer `eval`.
  - **Option B (`redirect.ts:18`)** : `?to=` non filtré → **open redirect** → hameçonnage. Correction : **liste blanche** stricte de destinations.
  - **Option C (`insecurity.ts:54`)** : clé JWT en dur (déjà vue au Lab 1). Correction : coffre / variable d'env.
- **Correction SQLi** : requête paramétrée (`$1`, `$2` + `replacements`), cf. `data/static/codefixes/loginAdminChallenge_4_correct.ts`.
- **Message central** : *données ≠ code*.

---

## Lab 3 — SCA

- **Pourquoi `trivy fs` ne trouve rien ?** Pas de `package-lock.json` (`.npmrc` : `package-lock=false`). Sans inventaire de versions → pas de SCA.
- **Où trouver les deps ?** Dans l'**image** (le `npm install` y a eu lieu) → 52 vulns.
- **CVE critiques réelles** : `jsonwebtoken 0.4.0` (CVE-2015-9235), `lodash 2.4.2` (CVE-2019-10744, prototype pollution), `crypto-js 3.3.0` (CVE-2023-46233), `marsdb` (injection de commande, **sans correctif**), `tar` (DoS).
- **Priorisation** : sévérité + correctif disponible (`--ignore-unfixed`) + dépendance réellement utilisée.

---

## Lab 4 — Conteneur

- **OS** : 31 findings, 1 HIGH = `libssl3` / CVE-2026-14456 (OpenSSL DoS).
- **Bonnes pratiques du Dockerfile racine** : distroless (`gcr.io/distroless/nodejs24-debian13`), non-root (`USER 65532`), multi-stage (`AS installer`).
- **Exercice §4.5** : `infrastructure/Dockerfile` utilise `node:20-bookworm-slim` (Debian complet = plus de surface). Rappel : dossier `infrastructure/` volontairement vulnérable.
- **5 réflexes** : base minimale, non-root, versions épinglées, multi-stage, scan en CI avec `--exit-code 1`.

---

## Lab 5 — IaC

- **8 misconfigs** dans `terraform/networking.tf` :
  - CRITICAL : HTTP en clair (AWS-0054, l.157), egress illimité ×3 (AWS-0104).
  - HIGH : LB exposé (AWS-0053), en-têtes invalides non écartés (AWS-0052), IP publique par défaut ×2 (AWS-0164).
- **Clé privée en dur** : `aws_iam_server_certificate` (~ligne 171). Recoupe le Lab 1.
- **Exercice §5.4** : bloquer sur CRITICAL d'abord, resserrer ensuite selon la maturité. Ne pas tout bloquer d'un coup.

---

## Lab 6 — DAST

- **Résumé réel** : WARN: 8, PASS: 59, FAIL: 0.
- **Alertes Medium** : CSP Header Not Set, Cross-Domain Misconfiguration.
- **Lien pédagogique** : la **CSP manquante** explique le XSS du Lab 7 §7.3. Le baseline (passif) trouve les défauts de config ; le scan actif trouverait les injections.
- **`exit code 2` = normal** (ZAP a trouvé des WARN).

---

## Lab 7 — Exploitation

- **§7.1 SQLi login** : `admin@juice-sh.op'--` (ou `' OR 1=1--`) → connecté admin. Le `--` commente la vérif du mot de passe.
- **§7.2 UNION** : 24 lignes renvoyées, tous les emails + hash MD5. `admin123` derrière le hash MD5.
- **§7.3 XSS** : `<iframe src="javascript:alert(\`xss\`)">` dans la recherche → popup.
- **§7.4 Access Control** : `http://localhost:3000/#/administration`. Cacher un lien ≠ contrôler l'accès.
- **§7.5 JWT forgé** : clé privée fuitée → forger un jeton pour n'importe qui. **Bouquet final** reliant Labs 1, 2 et 7. Un secret exposé doit être **révoqué**.

---

## Lab 8 — Pipeline

- **Exercice §8.2** : (1) `build-and-scan-image` avec `exit-code: '1'` ; (2) job `sast` → `upload-sarif` ; (3) `dast` avec `needs: build-and-scan-image`.
- **Ordre** : *fail fast* — le moins cher/plus rapide d'abord (secrets → SAST → image → IaC → DAST).
- **Politique de gate** : progressive (observer → bloquer le nouveau → resserrer). DevSecOps = technique **+ culture**.

---

## Erreurs fréquentes des apprenants

| Erreur | Correction à apporter |
|--------|-----------------------|
| Confondre SAST et DAST | SAST = code (dedans) ; DAST = app en marche (dehors). |
| Croire qu'un scan « vert » = « sécurisé » | Un scan ne trouve que ce qu'il connaît. Absence d'alerte ≠ absence de faille. |
| Vouloir corriger les 69 alertes Gitleaks | On **priorise** (clés privées d'abord) et on trie les faux positifs. |
| Oublier `--network host` sur ZAP | Sans ça, le conteneur ZAP ne joint pas `localhost:3000`. |
| Paniquer sur `exit code 2` de ZAP | C'est voulu : ZAP signale des alertes. |
| Vouloir déployer le dossier `infrastructure/` | **Jamais** : volontairement vulnérable (challenges). |
