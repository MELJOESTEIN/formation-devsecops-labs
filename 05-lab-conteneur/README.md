# Lab 4 — Sécurité des conteneurs avec Trivy

⏱️ **30 minutes** · 🧩 Difficulté : ⭐⭐ · 🎯 Objectif : scanner une image Docker (OS + config) et savoir lire un `Dockerfile` bien ou mal durci

📍 **Où dans la chaîne ?** À l'étape **packaging / build de l'image**, avant le déploiement.

```
CODE ─► Secrets ─► SAST ─► SCA ─► [🔒 CONTENEUR] ─► IaC ─► DAST
                                   Trivy image
                                  ◄── vous êtes ici
```

---

## 4.1 — Une image, ce n'est pas que votre app

Une image Docker est un empilement de **couches** :

```
┌─────────────────────────────────┐
│  Votre application (build/app.js)│  ← Lab 2 (SAST)
├─────────────────────────────────┤
│  Dépendances (node_modules)      │  ← Lab 3 (SCA)
├─────────────────────────────────┤
│  Runtime (Node.js)               │
├─────────────────────────────────┤
│  Bibliothèques système (openssl…)│  ← CE LAB
│  Système d'exploitation (Debian) │  ← CE LAB
└─────────────────────────────────┘
```

Vous héritez des failles de **toutes** ces couches. Un OS de base non patché = des failles, même si votre code est parfait.

---

## 4.2 — Scanner la couche système de l'image

Au Lab 3 on a regardé les bibliothèques applicatives. Regardons maintenant les **paquets du système d'exploitation** :

```bash
trivy image --scanners vuln --pkg-types os bkimminich/juice-shop:v20.2.0
```

Résultat (réel) :

```
bkimminich/juice-shop:v20.2.0 (debian 13.6)
Total: 31 (UNKNOWN: 0, LOW: 12, MEDIUM: 18, HIGH: 1, CRITICAL: 0)
```

31 failles côté OS, dont **1 HIGH** : `CVE-2026-14456` sur `libssl3` (OpenSSL, déni de service). Peu de critiques ici car l'image est basée sur **distroless** (voir plus bas) — une base minimale, donc **peu de surface d'attaque**. C'est déjà une bonne pratique !

> 💡 **Note formateur** : comparez avec une image « grasse ». Une base `node:24` (Debian complet) contient des **centaines** de paquets → beaucoup plus de CVE. Moins il y a de choses dans l'image, moins il y a de failles. C'est le principe de **surface d'attaque minimale**.

---

## 4.3 — Vue complète et rapport

Pour la vision d'ensemble (app + OS) :

```bash
trivy image --severity CRITICAL,HIGH bkimminich/juice-shop:v20.2.0
```

Pour un rapport exploitable en CI (table lisible + code de sortie qui **fait échouer le build** si des failles critiques existent) :

```bash
trivy image --severity CRITICAL,HIGH --exit-code 1 --ignore-unfixed \
  bkimminich/juice-shop:v20.2.0
```

- `--exit-code 1` → Trivy renvoie une **erreur** s'il trouve des failles → le pipeline s'arrête. C'est la **« gate »** de sécurité (Lab 8).
- `--ignore-unfixed` → on ne bloque que sur ce qui est **corrigeable**, pour ne pas paralyser l'équipe sur des CVE sans patch.

> 🎯 **Ce qu'il faut retenir** : un scanner en CI ne sert à rien s'il n'a pas le **pouvoir de bloquer**. `--exit-code 1` transforme un rapport passif en garde-fou actif.

---

## 4.4 — Analyser le `Dockerfile` (bonnes pratiques)

Au-delà des CVE, la **façon d'écrire** le Dockerfile compte. Trivy sait auditer ça :

```bash
trivy config Dockerfile
```

Résultat (réel) :

```
Tests: 27 (SUCCESSES: 25, FAILURES: 2)
Failures: 2 (LOW: 1, MEDIUM: 1)
DS-0001 (MEDIUM): Specify a tag in the 'FROM' statement for image 'gcr.io/distroless/nodejs24-debian13'
```

**Bonne surprise** : le Dockerfile de Juice Shop est **plutôt bien fait** (25 tests réussis) ! Ouvrons-le pour voir *pourquoi* :

```bash
grep -nE 'FROM|USER|COPY --chown|EXPOSE' Dockerfile
```

Vous verrez notamment :

| Bonne pratique | Ligne | Pourquoi c'est bien |
|----------------|-------|---------------------|
| `FROM gcr.io/distroless/nodejs24-debian13` | image finale | **Distroless** = pas de shell, pas de gestionnaire de paquets → surface d'attaque minimale |
| `USER 65532` | avant le `CMD` | L'app tourne en **utilisateur non-root** → si compromise, l'attaquant n'est pas root |
| *multi-stage build* (`AS installer`) | en-tête | On construit dans une image lourde, on ne garde que le nécessaire dans l'image finale |

> 💡 **Note formateur** : c'est l'occasion de montrer du **bon** code, pas que du vulnérable. « Voilà à quoi ressemble une image durcie : distroless + non-root + multi-stage. Retenez ces 3 réflexes. »

### Les 2 défauts restants ?

`DS-0001 (MEDIUM)` : l'image de base n'a pas de **tag de version figé** (`:latest` implicite). Bonne pratique : épingler une version précise (`@sha256:...`) pour des builds reproductibles — exactement comme on a épinglé `juice-shop:v20.2.0`.

---

## 4.5 — Contraste : un Dockerfile *mal* fait

> ✋ **À vous de jouer** (5 min) : le dépôt contient un **second** Dockerfile, volontairement moins bon, dans `infrastructure/`. Scannez-le et comparez.

```bash
trivy config infrastructure/Dockerfile
```

<details>
<summary>👉 Ce qu'on observe</summary>

Le Dockerfile de `infrastructure/` utilise une base `node:20-bookworm-slim` (Debian complet, plus de surface) au lieu du distroless. C'est un **rappel** : ce dossier `infrastructure/` est **volontairement vulnérable** (challenges Juice Shop) — **à ne jamais utiliser pour un vrai déploiement**.

**Leçon** : deux Dockerfiles dans un même projet peuvent avoir des niveaux de sécurité très différents. On audite **chaque** image qu'on construit.

</details>

---

## 4.6 — Récapitulatif : les 5 réflexes « image durcie »

1. **Base minimale** (distroless, alpine, slim) → moins de CVE.
2. **Utilisateur non-root** (`USER`) → limite les dégâts en cas de compromission.
3. **Versions épinglées** (`FROM ...@sha256`, deps figées) → builds reproductibles.
4. **Multi-stage build** → l'image finale ne contient pas les outils de build.
5. **Scan en CI avec `--exit-code 1`** → on bloque avant de déployer.

---

## ✅ Checklist de fin de lab

- [ ] J'ai scanné les couches **OS** de l'image (31 findings, 1 HIGH).
- [ ] Je sais faire **échouer un build** avec `--exit-code 1`.
- [ ] J'ai audité le `Dockerfile` avec `trivy config` et identifié 3 bonnes pratiques (distroless, non-root, multi-stage).
- [ ] Je connais les 5 réflexes d'une image durcie.

➡️ **Lab suivant : [Lab 5 — Infrastructure as Code (IaC)](../06-lab-iac/README.md)**
