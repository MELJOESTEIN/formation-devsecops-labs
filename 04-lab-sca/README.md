# Lab 3 — Dépendances vulnérables (SCA) avec Trivy

⏱️ **45 minutes** · 🧩 Difficulté : ⭐⭐ · 🎯 Objectif : découvrir que la majorité du risque vient du code que vous **n'avez pas écrit** — les bibliothèques tierces

📍 **Où dans la chaîne ?** À l'étape **build**, en même temps que le SAST.

```
CODE ─► Secrets ─► SAST ─► [🔒 SCA] ─► Conteneur ─► IaC ─► DAST
                            Trivy
                           ◄── vous êtes ici
```

---

## 3.1 — Le code que vous n'avez pas écrit

Une application moderne, c'est **~10 % votre code** et **~90 % des dépendances** (bibliothèques open source). Chaque `npm install` tire des dizaines, voire des **centaines** de paquets, qui en tirent d'autres…

**SCA** = *Software Composition Analysis* = analyser la **composition** logicielle : quelles bibliothèques utilisez-vous, et **ont-elles des failles connues (CVE)** ?

Analogie : vous cuisinez un plat maison (votre code), mais avec des **conserves achetées** (les dépendances). Le SCA vérifie qu'aucune conserve n'est **périmée ou rappelée par le fabricant**.

> 💡 **Note formateur** — l'attaque de la chaîne d'approvisionnement (*supply chain*) est devenue la menace n°1 (log4shell, event-stream, xz…). Votre code peut être parfait : si une dépendance est vérolée, vous êtes vulnérable.

---

## 3.2 — Un piège pédagogique : scanner les *sources* ne suffit pas

Essayons d'abord de scanner le **dépôt** (les sources) avec Trivy :

```bash
cd ~/juice-shop   # ← la racine de VOTRE clone Juice Shop (adaptez le chemin)
trivy fs --scanners vuln --severity CRITICAL,HIGH .
```

Résultat : **presque rien**. 🤔

> ✋ **À vous de jouer** : pourquoi Trivy ne trouve-t-il (quasi) aucune dépendance vulnérable dans les sources ?

<details>
<summary>👉 Réponse</summary>

Parce que ce dépôt **ne contient pas de fichier de verrouillage** (`package-lock.json`) — regardez le fichier `.npmrc`, il y a `package-lock=false`. Sans *lockfile*, Trivy ne sait pas **quelles versions exactes** seront installées : il ne peut donc pas les comparer à sa base de CVE.

**Leçon DevSecOps n°1** : le SCA a besoin d'un **inventaire précis** des versions. C'est le rôle du *lockfile* (`package-lock.json`, `yarn.lock`…) ou d'un **SBOM** (*Software Bill of Materials* — la « liste des ingrédients » de votre logiciel). **Pas d'inventaire = pas de SCA fiable.**

</details>

---

## 3.3 — Scanner là où les dépendances sont *réellement installées* : l'image

Les dépendances sont installées **dans l'image Docker** (le `npm install` a eu lieu au build de l'image). Scannons donc l'image, en ne gardant que les **bibliothèques applicatives** :

```bash
trivy image --scanners vuln --pkg-types library --severity CRITICAL,HIGH bkimminich/juice-shop:v20.2.0
```

Cette fois, jackpot 🎯 :

```
Node.js (node-pkg)
Total: 52 (HIGH: 44, CRITICAL: 8)
```

**52 vulnérabilités** dans les bibliothèques Node.js, dont **8 critiques** !

> 🎯 **Leçon DevSecOps n°2** : on scanne l'artefact **tel qu'il sera déployé** (l'image), pas seulement le code source. C'est pour ça que le Lab 4 (conteneur) est le prolongement naturel de celui-ci.

---

## 3.4 — Lire les résultats critiques

Voici un extrait des vulnérabilités **CRITICAL** trouvées (réelles, sur cette image) :

| Bibliothèque | Version installée | CVE | Problème | Corrigé dans |
|--------------|-------------------|-----|----------|--------------|
| `jsonwebtoken` | 0.4.0 | CVE-2015-9235 | Contournement de la vérification de signature | 4.2.2 |
| `lodash` | 2.4.2 | CVE-2019-10744 | **Pollution de prototype** | 4.17.12 |
| `crypto-js` | 3.3.0 | CVE-2023-46233 | PBKDF2 1000× plus faible que prévu | 4.2.0 |
| `marsdb` | 0.6.11 | GHSA-5mrr-rgp6-x4gr | **Injection de commande** | *(aucun correctif)* |
| `tar` | 6.2.1 | CVE-2026-59873 | Déni de service (bombe gzip) | 7.5.19 |

> 💡 Ces bibliothèques sont **volontairement vieilles** dans Juice Shop (challenges *« Vulnerable Library »* et *« Known Vulnerable Component »*). Mais dans un vrai projet, ce sont **exactement** les alertes que vous verriez avec des dépendances non mises à jour.

### Anatomie d'une alerte

Prenons `lodash 2.4.2 → CVE-2019-10744` :
- **`lodash`** : une bibliothèque utilitaire ultra-répandue.
- **`2.4.2`** : la version installée (très ancienne).
- **CVE-2019-10744** : l'identifiant public de la faille (base *Common Vulnerabilities and Exposures*).
- **Correctif : `4.17.12`** → la solution est souvent simple : **mettre à jour**.

---

## 3.5 — Prioriser : toutes les CVE ne se valent pas

52 alertes, on corrige quoi en premier ? On croise **deux critères** :

1. **Sévérité** (score CVSS) : CRITICAL/HIGH d'abord.
2. **Existe-t-il un correctif ?** Une CVE **avec** correctif (`FixedVersion`) est *actionnable* tout de suite ; sans correctif, il faut mitiger autrement (ou retirer la dépendance).

Filtrons les vulnérabilités **corrigeables** (option `--ignore-unfixed`) :

```bash
trivy image --scanners vuln --pkg-types library \
  --severity CRITICAL,HIGH --ignore-unfixed \
  bkimminich/juice-shop:v20.2.0
```

> 🎯 **Ce qu'il faut retenir** : le SCA génère beaucoup d'alertes. La compétence, c'est de **prioriser** : critique + correctif dispo + dépendance réellement utilisée = à corriger en premier.

---

## 3.6 — La bonne pratique : le SBOM

Un **SBOM** (*Software Bill of Materials*) est la liste officielle de tous les composants de votre logiciel. C'est devenu une **exigence réglementaire** (décret US, Cyber Resilience Act européen).

Bonne nouvelle : Juice Shop sait en générer un (voir `package.json`, script `sbom`), et Trivy sait en générer aussi :

```bash
# Générer un SBOM (format CycloneDX) directement depuis l'image :
trivy image --format cyclonedx --output juice-shop-sbom.json bkimminich/juice-shop:v20.2.0
```

Ce fichier peut ensuite être **re-scanné à tout moment** : quand une *nouvelle* CVE sort demain sur une lib que vous utilisez, vous le saurez sans reconstruire l'app.

```bash
# Re-scanner un SBOM existant :
trivy sbom juice-shop-sbom.json --severity CRITICAL,HIGH
```

---

## 3.7 — Et `npm audit` ?

Sur un projet Node.js avec un `package-lock.json`, l'outil natif est :

```bash
npm audit                 # liste les dépendances vulnérables
npm audit fix             # tente de corriger automatiquement (mises à jour compatibles)
```

> ⚠️ Ici `npm audit` **ne fonctionne pas directement** : pas de lockfile (`package-lock=false` dans `.npmrc`) et pas de `node_modules`. C'est le même enseignement qu'au 3.2 : **sans inventaire, pas d'audit**. Sur vos propres projets, committez le lockfile et lancez `npm audit` en CI.

---

## ✅ Checklist de fin de lab

- [ ] J'ai compris pourquoi scanner les sources sans lockfile ne donne rien.
- [ ] J'ai scanné l'image et trouvé **52 vulns de bibliothèques** (8 critiques).
- [ ] Je sais lire une alerte (paquet, version, CVE, correctif).
- [ ] Je sais **prioriser** (sévérité + correctif dispo).
- [ ] Je sais ce qu'est un **SBOM** et pourquoi c'est important.

➡️ **Lab suivant : [Lab 4 — Sécurité des conteneurs](../05-lab-conteneur/README.md)**
