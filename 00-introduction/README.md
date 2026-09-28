# Module 0 — Introduction : DevSecOps & Juice Shop

⏱️ **30 minutes** · 🎓 Théorie + démonstration

---

## 0.1 — Où en est-on ? (rappel J1 & J2)

Sur les deux premiers jours, vous avez vu :

- **J1 — DevOps** : la culture, les cycles courts, l'automatisation (CI/CD), l'*infrastructure as code*.
- **J2 — Fondamentaux sécu** : le Top 10 OWASP, la notion de vulnérabilité, de menace, de surface d'attaque.

**Aujourd'hui (J3), on fusionne les deux : le DevSecOps.**

---

## 0.2 — C'est quoi le DevSecOps, en une phrase ?

> **DevSecOps = intégrer la sécurité comme une responsabilité partagée, automatisée et continue, à *chaque* étape du cycle de vie logiciel — au lieu de la reléguer à un audit final.**

### L'ancienne manière (à éviter)

```
Dev ──► Build ──► Test ──► Déploiement ──► 🔒 AUDIT SÉCU (une fois par an)
                                                    │
                                                    ▼
                                    « On a trouvé 200 failles ! »
                                    → Trop tard, trop cher, tout le monde se renvoie la balle.
```

La sécurité arrive **à la fin**, comme un contrôle qui bloque tout. Résultat : conflits, retards, failles corrigées des mois trop tard.

### La manière DevSecOps (l'objectif)

La sécurité est **distribuée** tout au long de la chaîne, automatisée, et donne un retour **immédiat** au développeur.

```
Dev ─► Commit ─► Build ─► Deploy ─► Run
 🔒       🔒        🔒        🔒       🔒
IDE    secrets    SAST     image    DAST
       Gitleaks   SCA      IaC      ZAP
```

---

## 0.3 — Le principe clé : « Shift Left »

Imaginez une chaîne de production qui va de gauche (l'idée, le code) à droite (la production).

> **« Shift Left » = déplacer la détection des problèmes le plus à *gauche* possible, c'est-à-dire le plus *tôt* possible.**

**Pourquoi ?** Parce que le coût de correction d'une faille **explose** avec le temps :

```
Coût de correction d'un bug/faille selon le moment où on le trouve :

 Conception   │ ▏ 1×
 Code (IDE)   │ ▍ ~5×
 Build/Test   │ ██ ~10×
 Recette      │ ████ ~15×
 PRODUCTION   │ ████████████████████████ ~100× (voire une fuite de données !)
             └────────────────────────────────────────►
              (plus on détecte tard, plus c'est cher)
```

Corriger une injection SQL **dans l'éditeur du développeur** prend 5 minutes.
La corriger **après une fuite de la base de données clients en production** peut coûter des millions (amende RGPD, réputation, incident…).

> 🎯 **Ce qu'il faut retenir** : tout ce qu'on fait aujourd'hui vise à détecter les failles **le plus tôt possible**, automatiquement, sans ralentir les développeurs.

---

## 0.4 — La boîte à outils du DevSecOps

On classe les outils selon **ce qu'ils regardent** :

| Famille | Nom complet | Que regarde-t-il ? | Analogie | Notre outil |
|---------|-------------|--------------------|----------|-------------|
| **Secrets** | Secret Scanning | Mots de passe / clés oubliés dans le code | Chercher un post-it « mot de passe » collé sous le clavier | **Gitleaks** |
| **SAST** | Static Application Security Testing | Le **code source**, sans l'exécuter | Relire une recette de cuisine pour repérer les erreurs | **Semgrep** |
| **SCA** | Software Composition Analysis | Les **bibliothèques tierces** (dépendances) | Vérifier que les ingrédients achetés ne sont pas périmés | **npm audit / Trivy** |
| **Conteneur** | Container Scanning | L'**image Docker** (OS + libs) | Inspecter le camion de livraison entier | **Trivy** |
| **IaC** | Infrastructure as Code Scanning | Les fichiers **Terraform / YAML** | Vérifier les plans du bâtiment avant de construire | **Trivy config** |
| **DAST** | Dynamic Application Security Testing | L'**application en marche** | Tester toutes les portes en secouant les poignées | **OWASP ZAP** |

> 💡 **Note formateur** : insistez sur SAST vs DAST — c'est LA confusion classique des débutants.
> - **SAST** = « boîte blanche », on lit le code (on voit *l'intérieur*), mais on ne sait pas si la faille est réellement exploitable → beaucoup de **faux positifs**.
> - **DAST** = « boîte noire », on attaque l'app comme un vrai pirate (on voit *l'extérieur*), donc si ça marche c'est réel → mais on ne sait pas *où* dans le code corriger.
> **Les deux sont complémentaires**, pas concurrents.

---

## 0.5 — Notre cobaye : OWASP Juice Shop 🧃

**OWASP Juice Shop** est *« l'application web non sécurisée la plus moderne et la plus sophistiquée »*. C'est un vrai site e-commerce (Angular + Node.js/Express + base SQLite), mais **truffé volontairement de failles**.

- Maintenue par l'**OWASP** (l'organisation de référence en sécurité web).
- Contient **plus de 100 challenges** couvrant tout le Top 10 OWASP.
- Un **tableau des scores** (*Score Board*) suit votre progression… mais il est **caché** : le trouver est le tout premier challenge !

### Pourquoi c'est parfait pour une formation DevSecOps ?

Parce qu'on a **le code source complet ET l'application qui tourne**. On peut donc :

1. Scanner le code (SAST, secrets, dépendances) → *shift left*
2. Scanner l'image et l'infra
3. Attaquer l'app en marche (DAST + exploitation manuelle)
4. **Faire le lien** : « le scanner a signalé la ligne 34 de `login.ts` → voilà comment on l'exploite réellement ».

> ⚠️ **Attention légale** : Juice Shop est fait pour être attaqué **sur votre propre machine**. Les mêmes techniques sur un site tiers sans autorisation = **délit pénal**.

---

## 0.6 — Aperçu de ce qu'on va trouver (démonstration formateur)

> 💡 **Note formateur** — Démo live de 5 min pour donner envie. Juice Shop tourne déjà sur `:3000`.
> Montrez le bypass d'authentification en une ligne, sans mot de passe :

```bash
curl -s -X POST http://localhost:3000/rest/user/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"'"'"' OR 1=1--","password":"peu importe"}'
```

Résultat : l'application renvoie un **jeton de connexion valide pour le compte administrateur**, sans connaître le mot de passe. 😱

C'est une **injection SQL** (OWASP A03). Aujourd'hui, on va :
- la **trouver dans le code** avec Semgrep (Lab 2),
- la **détecter sur l'app** avec ZAP (Lab 6),
- l'**exploiter proprement** dans le navigateur (Lab 7),
- et voir **comment la corriger**.

---

## ✅ Checklist de fin de module

- [ ] Je sais expliquer « DevSecOps » et « Shift Left » avec mes mots.
- [ ] Je connais la différence entre **SAST** et **DAST**.
- [ ] Je sais ce qu'est OWASP Juice Shop et pourquoi on l'utilise.
- [ ] J'ai compris que scanner sans autorisation est illégal hors environnement de formation.

➡️ **Module suivant : [Lab 0 — Mise en place de l'environnement](../01-setup/README.md)**
