# Lab 8 — Assembler le pipeline DevSecOps

⏱️ **30 minutes** · 🧩 Difficulté : ⭐⭐ · 🎯 Objectif : réunir les 6 outils de la journée en **un pipeline CI/CD** automatisé, et comprendre la notion de *gate*

📍 **Vue d'ensemble** : c'est le module qui **connecte tout**. Jusqu'ici on a lancé chaque outil à la main. Maintenant, on les fait tourner **automatiquement à chaque `git push`**.

```
git push
   │
   ▼
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ 1.Secrets│─►│ 2. SAST  │─►│ 3. SCA + │─►│ 4. IaC   │─►│ 5. DAST  │─► ✅ Déploiement
│ Gitleaks │  │ Semgrep  │  │  Image   │  │ Trivy    │  │ ZAP      │
│          │  │          │  │  Trivy   │  │ config   │  │          │
└────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘
     │             │             │             │             │
     ▼             ▼             ▼             ▼             ▼
  ⛔ si secret  ⛔ si faille  ⛔ si CVE     ⛔ si misconfig ⚠️ si alerte
     bloque       critique      critique      critique       (rapport)
```

---

## 8.1 — Le concept clé : la « Security Gate »

Une **gate** (barrière) est un point de contrôle qui peut **arrêter** le pipeline. Techniquement, c'est un job qui renvoie un **code de sortie non nul** en cas de problème → la plateforme CI marque le pipeline comme **échoué** → le code **ne part pas** plus loin.

On a déjà vu le mécanisme dans chaque lab :

```bash
trivy image --severity CRITICAL,HIGH --exit-code 1 ...   # ⛔ échoue si CVE critique
trivy config --severity CRITICAL,HIGH --exit-code 1 ...  # ⛔ échoue si misconfig
```

> 🎯 **Ce qu'il faut retenir** : un scanner sans gate = un rapport que personne ne lit. Un scanner **avec** gate = une faille qui **bloque réellement** la livraison. C'est ce qui distingue un « on a des outils » d'un « on fait du DevSecOps ».

---

## 8.2 — Le pipeline complet (fourni)

Deux versions clés en main sont fournies dans ce dépôt de formation :

| Plateforme | Fichier | À copier dans |
|------------|---------|---------------|
| **GitHub Actions** | [`pipeline-exemples/github/devsecops-pipeline.yml`](../pipeline-exemples/github/devsecops-pipeline.yml) | `.github/workflows/` de votre projet |
| **GitLab CI** | [`pipeline-exemples/gitlab/.gitlab-ci.yml`](../pipeline-exemples/gitlab/.gitlab-ci.yml) | racine de votre projet |

Ouvrez le fichier correspondant à votre plateforme et **lisez-le en entier** : chaque job est commenté et renvoie au lab correspondant.

### Exercice de lecture

> ✋ **À vous de jouer** (10 min) : dans le fichier GitHub Actions, retrouvez :
> 1. Le job qui **bloque** en cas de CVE critique (indice : `exit-code`).
> 2. Le job qui **publie** ses résultats dans l'onglet *Security* de GitHub (indice : `sarif`).
> 3. Le job DAST qui attend qu'un **autre job** finisse avant de démarrer (indice : `needs`).

<details>
<summary>👉 Réponses</summary>

1. `build-and-scan-image` avec `exit-code: '1'` sur l'action Trivy.
2. `sast` : l'étape `upload-sarif` envoie `semgrep.sarif`. (Gitleaks et Trivy peuvent aussi produire du SARIF.)
3. `dast` : il a `needs: build-and-scan-image` → il ne démarre qu'après un build+scan d'image réussi (il faut une image saine avant de l'attaquer).

</details>

---

## 8.3 — L'ordre compte : pourquoi cette séquence ?

On n'ordonne pas les jobs au hasard. Principe : **le moins cher et le plus rapide d'abord** (*fail fast*).

| Ordre | Étape | Rapidité | Pourquoi à cette place |
|-------|-------|----------|------------------------|
| 1 | Secrets | ⚡ secondes | Un secret fuité = urgence absolue, et c'est instantané à détecter |
| 2 | SAST | 🚶 1-4 min | Analyse le code, pas besoin de build |
| 3 | SCA + Image | 🐢 quelques min | Nécessite de **builder** l'image |
| 4 | IaC | ⚡ secondes | Peut tourner en parallèle |
| 5 | DAST | 🐌 le plus long | Nécessite une **app démarrée** → forcément à la fin |

> 💡 **Note formateur** : insistez sur *fail fast*. Inutile de builder une image (5 min) si un secret a déjà été détecté en 3 secondes. On échoue **au plus tôt** pour donner un retour **rapide** au dev — c'est aussi ça, le shift-left.

---

## 8.4 — Tout lancer en local (répétition avant la CI)

Avant de brancher la CI, on peut rejouer toute la chaîne localement grâce au script fourni :

```bash
cd formation-devsecops
./scripts/run-all-scans.sh
```

Il lance Gitleaks → Semgrep → Trivy (fs, image, config) et écrit les rapports dans `formation-devsecops/rapports/`. C'est exactement ce que fera la CI, mais sur votre machine.

> 💡 Le **DAST/ZAP** se lance séparément (Lab 6) car il attaque l'app **en marche** — il n'a pas sa place dans un scan de code statique.

---

## 8.5 — Politique de gate : bloquer sans braquer les équipes

Bloquer sur **tout**, dès le premier jour, c'est le meilleur moyen de faire **détester** la sécurité par les développeurs (et de voir le pipeline désactivé en douce). Stratégie d'adoption progressive :

1. **Semaine 1 — Observer** : les scans tournent mais **ne bloquent pas** (mode « rapport »). On mesure la dette existante.
2. **Semaine 2-4 — Bloquer le nouveau** : on ne bloque que sur les **nouvelles** failles critiques introduites (`FAIL-NEW` de ZAP, *diff* de Semgrep). L'existant est traité en fond.
3. **Ensuite — Resserrer** : on abaisse peu à peu le seuil (CRITICAL, puis HIGH…) au rythme de la maturité de l'équipe.

> 🎯 **Ce qu'il faut retenir** : le DevSecOps est autant **culturel** que technique. La gate doit être **négociée** et **progressive**, sinon elle est contournée.

---

## 8.6 — Récapitulatif de la journée 🏁

Vous avez construit une chaîne de sécurité **complète** et compris chaque maillon :

| Lab | Outil | Détecte | Sur Juice Shop |
|-----|-------|---------|----------------|
| 1 | Gitleaks | Secrets | Clé privée RSA en dur |
| 2 | Semgrep | Failles de code (SAST) | Injection SQL `login.ts:34` |
| 3 | Trivy | Dépendances (SCA) | 52 vulns de bibliothèques |
| 4 | Trivy | Image conteneur | 31 failles OS + Dockerfile |
| 5 | Trivy config | IaC | 8 misconfigs Terraform |
| 6 | OWASP ZAP | App en marche (DAST) | En-têtes de sécurité manquants |
| 7 | Vous ! | Exploitation | Bypass admin, vol de base, XSS |
| 8 | CI/CD | Orchestration | Le pipeline qui bloque tout ça |

---

## ✅ Checklist finale

- [ ] Je comprends ce qu'est une **security gate** (`--exit-code 1`).
- [ ] J'ai lu et compris le pipeline (GitHub **ou** GitLab).
- [ ] Je sais **pourquoi** l'ordre des étapes est important (*fail fast*).
- [ ] J'ai relancé toute la chaîne en local avec `run-all-scans.sh`.
- [ ] Je sais qu'une politique de gate doit être **progressive**.

> 🎓 **Bravo !** Vous savez maintenant intégrer la sécurité à chaque étape d'une chaîne de livraison, lire les résultats des outils, et comprendre concrètement les failles qu'ils détectent.

➡️ **Pour aller plus loin : [Glossaire](../ressources/glossaire.md) · [Aide-mémoire](../ressources/cheatsheet.md) · [Planning](../ressources/planning.md)**
