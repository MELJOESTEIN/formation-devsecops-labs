# Lab 6 — Analyse dynamique (DAST) avec OWASP ZAP

⏱️ **45 minutes** · 🧩 Difficulté : ⭐⭐ · 🎯 Objectif : attaquer l'application **en marche** comme le ferait un pirate, sans voir son code

📍 **Où dans la chaîne ?** Tout à droite : sur l'**application déployée** (environnement de recette).

```
CODE ─► Secrets ─► SAST ─► SCA ─► Conteneur ─► IaC ─► [🔒 DAST]
                                                        OWASP ZAP
                                                       ◄── vous êtes ici
```

---

## 6.1 — SAST vs DAST : le grand duel (rappel)

| | **SAST** (Lab 2) | **DAST** (ce lab) |
|--|------------------|-------------------|
| Regarde | le **code source** | l'**application qui tourne** |
| Vision | « boîte blanche » (dedans) | « boîte noire » (dehors) |
| Trouve | la **ligne** vulnérable | une **faille réellement atteignable** |
| Faux positifs | beaucoup | peu (si ça marche, c'est réel) |
| Moment | au commit / build | après déploiement |
| Analogie | relire les plans du bâtiment | **secouer toutes les poignées de porte** |

> 🎯 Les deux sont **complémentaires**. Le SAST dit *« cette ligne semble risquée »* ; le DAST confirme *« oui, l'attaque passe »*. Ensemble = confiance maximale.

---

## 6.2 — L'outil : OWASP ZAP

**ZAP** (*Zed Attack Proxy*) est le scanner de sécurité web open source de référence (par l'OWASP). Il peut :

- **explorer** (spider) le site pour découvrir toutes les pages/API,
- lancer des **attaques passives** (analyser les réponses sans rien casser),
- lancer des **attaques actives** (envoyer de vraies charges d'attaque : injections, XSS…).

On utilise le **ZAP Baseline Scan** : rapide, **passif** (ne casse rien), parfait en CI. Il tourne dans un conteneur Docker — rien à installer.

---

## 6.3 — Lancer le scan baseline

Assurez-vous que Juice Shop tourne (`docker ps` doit montrer `juice-shop`). Puis, depuis un dossier où écrire le rapport :

```bash
cd formation-devsecops/rapports 2>/dev/null || mkdir -p formation-devsecops/rapports && cd formation-devsecops/rapports

docker run --rm --network host \
  -v "$(pwd):/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t http://localhost:3000 -r zap-report.html
```

| Morceau | Rôle |
|---------|------|
| `--network host` | Le conteneur ZAP partage le réseau de la machine → il atteint `localhost:3000` |
| `-v "$(pwd):/zap/wrk:rw"` | On monte le dossier courant pour **récupérer le rapport** |
| `zap-baseline.py` | Le script de scan passif |
| `-t http://localhost:3000` | La cible |
| `-r zap-report.html` | Le rapport HTML à générer |

> 💡 **Note formateur** : le scan prend **2 à 5 minutes** (spider + analyse passive). Lancez-le **au début du lab**, puis enchaînez sur la théorie 6.1/6.2 pendant qu'il tourne. La première fois, l'image ZAP (~3,7 Go) doit être téléchargée — faites-le **avant** la formation.

> ⚠️ **Attention** : le code de sortie de ZAP est **non nul** s'il trouve des alertes (`WARN`/`FAIL`). C'est **normal et voulu** — en CI, c'est ce qui fera « échouer » le job. Ne vous inquiétez pas d'un `exit code 2`.

---

## 6.4 — Lire le rapport

À la fin du scan, ZAP affiche un résumé — voici celui obtenu **réellement** sur cette machine :

```
FAIL-NEW: 0   FAIL-INPROG: 0   WARN-NEW: 8   WARN-INPROG: 0   INFO: 0   IGNORE: 0   PASS: 59
```

Lecture : **59 tests passés**, **0 échec bloquant** (`FAIL`), **8 avertissements** (`WARN`). Le baseline passif ne trouve pas de faille « rouge » (c'est le rôle du scan actif), mais il pointe **8 défauts de configuration**.

Ouvrez le rapport HTML dans le navigateur :

```bash
xdg-open zap-report.html   # ou double-cliquez sur le fichier
```

Chaque alerte contient :
- un **niveau de risque** (High / Medium / Low / Informational),
- la **description** de la faille,
- les **URLs concernées**,
- une **solution** recommandée.

Alertes réellement trouvées sur Juice Shop (analyse passive), les plus importantes en tête :

| Risque | Alerte ZAP | Ce que ça veut dire | OWASP |
|--------|------------|---------------------|-------|
| 🟠 Medium | **Content Security Policy (CSP) Header Not Set** | Pas de politique anti-injection de scripts → facilite le **XSS** (cf. Lab 7 §7.3) | A05 |
| 🟠 Medium | **Cross-Domain Misconfiguration** | Partage de ressources cross-origine trop permissif | A05 |
| 🟡 Low | **Cross-Origin-Embedder/Opener-Policy manquant** | En-têtes d'isolation de la page absents | A05 |
| 🟡 Low | **Dangerous JS Functions** | Usage de fonctions JS risquées (ex. `eval` — cf. Lab 2 §2.7) | A03 |
| 🟡 Low | **Timestamp Disclosure** | Fuite d'infos aidant la reconnaissance | A01 |
| ⚪ Info | **Modern Web Application** | ZAP a détecté une SPA (Angular) → conseille un scan avec navigateur | — |

> 💡 La **CSP manquante** est l'alerte la plus intéressante : c'est **exactement** ce qui rend le XSS du [Lab 7 §7.3](../08-lab-exploitation/README.md) possible. Le DAST et l'exploitation manuelle se **confirment** mutuellement.

> 🎯 **Ce qu'il faut retenir** : le baseline (passif) trouve surtout des **défauts de configuration** (en-têtes de sécurité manquants). L'analyse **active** (ci-dessous) trouverait en plus les injections. On commence par le passif car il est **sûr et rapide** — idéal en CI sur chaque déploiement.

---

## 6.5 — Aller plus loin : le scan actif (démonstration)

Le baseline ne fait **pas** d'attaque active (il ne veut rien casser). Pour chercher activement les injections SQL/XSS, il existe `zap-full-scan.py` :

```bash
# ⚠️ Scan ACTIF — envoie de vraies attaques. Uniquement sur VOTRE app de test !
docker run --rm --network host -v "$(pwd):/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable \
  zap-full-scan.py -t http://localhost:3000 -r zap-full-report.html
```

> ⚠️ Un scan actif peut **créer des données, déclencher des actions, ralentir le service**. On ne le lance **jamais** sur une prod ni sur un système qu'on n'a pas l'autorisation de tester. En CI, on le réserve à un environnement de recette dédié.

> 💡 **Note formateur** : par manque de temps, ne lancez le full-scan qu'en **démo** (il est plus long). L'essentiel est de comprendre la **différence passif/actif** et le **cadre légal**.

---

## 6.6 — Le maillon manquant : DAST + SAST se répondent

Reprenons l'injection SQL de `login.ts:34` (Lab 2) :

- **SAST** a dit : *« ligne 34, concaténation dangereuse »*.
- **DAST actif** confirmerait : *« j'ai envoyé `' OR 1=1--` sur `/rest/user/login` et j'ai obtenu un accès »*.
- Au **Lab 7**, **vous** allez le faire à la main.

C'est la **corrélation** qui fait la force d'un programme DevSecOps : plusieurs signaux qui pointent la même faille = priorité absolue de correction.

---

## ✅ Checklist de fin de lab

- [ ] J'ai lancé le **ZAP baseline** contre `localhost:3000` et obtenu un rapport HTML.
- [ ] Je sais lire une alerte (risque, description, solution).
- [ ] Je comprends la différence **passif** (sûr, CI) vs **actif** (puissant, encadré).
- [ ] Je sais expliquer pourquoi SAST **et** DAST sont complémentaires.
- [ ] Je connais le **cadre légal** d'un scan actif.

➡️ **Lab suivant : [Lab 7 — Exploitation manuelle du Top 10 OWASP](../08-lab-exploitation/README.md)**
