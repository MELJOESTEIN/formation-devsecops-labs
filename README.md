# 🛡️ Formation DevSecOps — Jour 3 : Sécuriser la chaîne avec OWASP Juice Shop

> **Support pédagogique — Labs pratiques pas à pas**
> Public : débutants en DevSecOps · Durée : 1 journée (09h30 → 17h00)
> Application cible : [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/) `v20.2.0`

---

## 🎯 L'objectif de la journée

Hier vous avez appris les *concepts* du DevSecOps. Aujourd'hui, on **met les mains dans le cambouis**.

Vous allez jouer le rôle d'un·e **ingénieur·e sécurité** qui rejoint l'équipe de développement de « Juice Shop », une boutique de jus de fruits en ligne. Le code est déjà écrit… et il est **truffé de failles** (c'est fait exprès : Juice Shop est l'application volontairement vulnérable de référence de l'OWASP).

Votre mission : **intégrer la sécurité à chaque étape de la chaîne de livraison** (le fameux *« Shift Left »*), en installant, une par une, les briques d'un pipeline DevSecOps — et surtout, **comprendre** ce que chaque outil détecte en exploitant vous-même les vulnérabilités.

À la fin de la journée, vous aurez construit un **pipeline de sécurité complet** et vous saurez :

- lire et interpréter le résultat d'un scanner de sécurité ;
- distinguer un vrai risque d'un faux positif ;
- exploiter manuellement les failles classiques du **Top 10 OWASP** ;
- assembler tout ça dans une CI/CD (GitHub Actions **et** GitLab CI).

---

## 🧭 La chaîne DevSecOps que nous allons construire

Chaque lab ajoute une brique. On avance de **gauche** (le poste du développeur) vers la **droite** (l'application en production).

```
   CODE          COMMIT           BUILD                    DEPLOY            RUN
    │               │                │                       │               │
    ▼               ▼                ▼                       ▼               ▼
┌────────┐    ┌───────────┐   ┌────────────┐         ┌────────────┐   ┌───────────┐
│  Dev   │    │  Secrets  │   │ SAST + SCA │         │ Conteneur  │   │   DAST    │
│  IDE   │    │ Gitleaks  │   │  Semgrep   │         │  + IaC     │   │   ZAP     │
│        │    │ (Lab 1)   │   │  npm/Trivy │         │  Trivy     │   │ (Lab 6)   │
│        │    │           │   │ (Lab 2-3)  │         │ (Lab 4-5)  │   │           │
└────────┘    └───────────┘   └────────────┘         └────────────┘   └───────────┘
                                                                            │
                              ┌─────────────────────────────────────────────┘
                              ▼
                     ┌──────────────────┐        ┌───────────────────────┐
                     │  Exploitation     │        │  Pipeline CI/CD        │
                     │  OWASP Top 10     │  ───►  │  qui orchestre le tout │
                     │  (Lab 7)          │        │  (Lab 8)               │
                     └──────────────────┘        └───────────────────────┘
     « SHIFT LEFT » : plus on détecte tôt (à gauche), moins ça coûte cher à corriger.
```

---

## 📚 Les modules

| # | Module | Ce qu'on fait | Outil | Durée |
|---|--------|---------------|-------|-------|
| 0 | [Introduction](00-introduction/README.md) | Comprendre le DevSecOps et Juice Shop | — | 30 min |
| 🔧 | [Lab 0 — Mise en place](01-setup/README.md) | Démarrer l'app et vérifier les outils | Docker | 30 min |
| 1 | [Lab 1 — Secrets](02-lab-secrets/README.md) | Trouver les secrets dans le code | **Gitleaks** | 45 min |
| 2 | [Lab 2 — SAST](03-lab-sast/README.md) | Analyser le code source | **Semgrep** | 60 min |
| 3 | [Lab 3 — Dépendances (SCA)](04-lab-sca/README.md) | Auditer les bibliothèques | **npm audit / Trivy** | 45 min |
| 4 | [Lab 4 — Conteneur](05-lab-conteneur/README.md) | Scanner l'image Docker | **Trivy** | 30 min |
| 5 | [Lab 5 — Infra as Code](06-lab-iac/README.md) | Scanner le Terraform | **Trivy config** | 30 min |
| 6 | [Lab 6 — DAST](07-lab-dast/README.md) | Attaquer l'app en marche | **OWASP ZAP** | 45 min |
| 7 | [Lab 7 — Exploitation](08-lab-exploitation/README.md) | Exploiter le Top 10 OWASP à la main | Navigateur | 45 min |
| 8 | [Lab 8 — Pipeline CI/CD](09-lab-pipeline/README.md) | Tout assembler en pipeline | **GitHub / GitLab** | 30 min |

### 📎 Ressources

- 🗓️ [Planning détaillé de la journée](ressources/planning.md)
- 📖 [Glossaire DevSecOps](ressources/glossaire.md) — tous les acronymes expliqués simplement
- ⌨️ [Aide-mémoire des commandes](ressources/cheatsheet.md)
- ✅ [Corrigés (réservé au formateur)](ressources/corrections.md)

---

## 🖥️ Portail en ligne (companion à projeter)

Un **tableau de bord interactif** résume toute la journée (pipeline visuel, les 9 labs avec résultats réels, suivi de progression par apprenant) — idéal à **projeter en classe** :

**➡️ [Ouvrir le portail](https://claude.ai/artifact/XfY5xhJEtjcYxwRvae9bTK)**

> Le lien est privé par défaut. Pour le partager aux apprenants, utilisez le menu **Partager** sur la page de l'artifact. Le support détaillé (ci-dessous) reste la référence pas à pas.

---

## ⚡ Démarrage ultra-rapide

Vous êtes pressé·e ? Un seul script prépare tout l'environnement :

```bash
cd formation-devsecops
./scripts/setup.sh
```

Puis ouvrez [http://localhost:3000](http://localhost:3000) : Juice Shop doit s'afficher. 🧃

> Si le script échoue, pas de panique : le [Lab 0](01-setup/README.md) détaille chaque étape à la main.

---

## 📥 Installation (apprenants)

Vous avez reçu l'archive **`formation-devsecops.zip`** et vous devez cloner Juice Shop. Faites les deux :

```bash
# 1. Cloner l'application vulnérable (vous en avez besoin pour les labs de scan)
git clone https://github.com/juice-shop/juice-shop.git
cd juice-shop

# 2. Décompresser le support de formation À LA RACINE de ce clone
#    (adaptez le chemin vers l'archive qu'on vous a transmise)
unzip ~/Téléchargements/formation-devsecops.zip -d .
```

Vous devez obtenir cette structure :

```
juice-shop/                 ← votre clone (contient routes/, lib/, infrastructure/…)
├── routes/  lib/  infrastructure/  data/   ← le code à scanner
└── formation-devsecops/    ← le support (ce dossier)
    ├── README.md            ← commencez ici
    ├── 00-introduction/ … 09-lab-pipeline/
    ├── scripts/  ressources/  pipeline-exemples/
```

> ⚙️ Sous Linux/macOS, rendez les scripts exécutables une fois : `chmod +x formation-devsecops/scripts/*.sh`
> Ensuite, ouvrez [`formation-devsecops/README.md`](README.md) et suivez les modules dans l'ordre.

---

## 🧱 Prérequis (déjà installés sur les postes)

| Outil | Rôle | Vérifier avec |
|-------|------|---------------|
| Docker | Faire tourner l'app et les scanners | `docker --version` |
| Node.js + npm | Auditer les dépendances | `node --version` |
| Gitleaks | Scanner de secrets | `gitleaks version` |
| Semgrep | Analyse statique (SAST) | `semgrep --version` |
| Trivy | Conteneurs, dépendances, IaC | `trivy --version` |
| Git | Contrôle de version | `git --version` |

---

## 🗺️ Comment utiliser ce support

- **Formateur** : chaque lab est autonome et minuté. Les blocs `> 💡 Note formateur` vous donnent les points à insister et les pièges classiques. Les solutions complètes sont dans [`ressources/corrections.md`](ressources/corrections.md).
- **Apprenant** : suivez les labs **dans l'ordre**. Chaque commande est à recopier telle quelle. Les blocs `> ✋ À vous de jouer` sont des exercices : essayez **avant** de regarder la suite.

### Légende des encarts

> 💡 **Note formateur** — points clés à souligner à l'oral.

> ✋ **À vous de jouer** — exercice pratique à faire soi-même.

> ⚠️ **Attention** — piège fréquent ou point de sécurité important.

> 🎯 **Ce qu'il faut retenir** — le message essentiel du lab.

---

## ⚖️ Cadre légal et éthique

Juice Shop est conçu pour être attaqué : **c'est légal et prévu**. En revanche, les techniques apprises aujourd'hui ne doivent être utilisées que sur des systèmes que **vous êtes autorisé·e à tester**. Attaquer un système sans autorisation est un **délit** (en France : art. 323-1 et suivants du Code pénal).

> Le dossier `infrastructure/` et les fichiers `terraform/` du dépôt Juice Shop sont **volontairement non sécurisés** et font partie des challenges. Ne les utilisez **jamais** pour déployer une vraie infrastructure.

---

*Support généré pour une formation DevSecOps · basé sur OWASP Juice Shop v20.2.0*
