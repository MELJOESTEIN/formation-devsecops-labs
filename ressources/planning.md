# 🗓️ Planning de la journée (J3) — 09h30 → 17h00

Rythme calibré pour des **débutants**, avec de la marge. Adaptez selon le groupe : mieux vaut approfondir 6 labs que survoler les 9.

| Horaire | Durée | Module | Format |
|---------|-------|--------|--------|
| 09h30 – 10h00 | 30 min | **[Module 0](../00-introduction/README.md)** — Intro DevSecOps, Shift-Left, présentation Juice Shop + démo « choc » | Exposé + démo |
| 10h00 – 10h30 | 30 min | **[Lab 0](../01-setup/README.md)** — Mise en place (Docker, outils, Score Board) | Pratique guidée |
| 10h30 – 11h15 | 45 min | **[Lab 1](../02-lab-secrets/README.md)** — Secrets (Gitleaks) | Pratique |
| 11h15 – 11h30 | 15 min | ☕ **Pause** | — |
| 11h30 – 12h30 | 60 min | **[Lab 2](../03-lab-sast/README.md)** — SAST (Semgrep) *(module central)* | Pratique + exo |
| 12h30 – 13h30 | 60 min | 🍽️ **Pause déjeuner** | — |
| 13h30 – 14h15 | 45 min | **[Lab 3](../04-lab-sca/README.md)** — Dépendances / SCA (Trivy) | Pratique |
| 14h15 – 14h45 | 30 min | **[Lab 4](../05-lab-conteneur/README.md)** — Conteneur (Trivy image) | Pratique |
| 14h45 – 15h00 | 15 min | ☕ **Pause** | — |
| 15h00 – 15h30 | 30 min | **[Lab 5](../06-lab-iac/README.md)** — IaC (Trivy config) | Pratique |
| 15h30 – 16h00 | 30 min | **[Lab 6](../07-lab-dast/README.md)** — DAST (OWASP ZAP) | Pratique |
| 16h00 – 16h40 | 40 min | **[Lab 7](../08-lab-exploitation/README.md)** — Exploitation OWASP Top 10 *(le plus fun !)* | Pratique |
| 16h40 – 17h00 | 20 min | **[Lab 8](../09-lab-pipeline/README.md)** — Pipeline CI/CD + synthèse + questions | Exposé + démo |

---

## ⚠️ À préparer AVANT la formation (formateur)

- [ ] Sur chaque poste : Docker, Node, Gitleaks, Semgrep, Trivy, Git installés (`./scripts/setup.sh` vérifie tout).
- [ ] **Pré-télécharger les images Docker** (elles sont lourdes) sur chaque poste :
  ```bash
  docker pull bkimminich/juice-shop:v20.2.0     # ~500 Mo
  docker pull ghcr.io/zaproxy/zaproxy:stable     # ~3,7 Go  ← le plus long !
  ```
- [ ] Pré-remplir le cache Trivy (1er scan télécharge la base de CVE) :
  ```bash
  trivy image --download-db-only
  ```
- [ ] Tester `./scripts/setup.sh` une fois : Juice Shop doit répondre sur `:3000`.
- [ ] Avoir les [corrigés](corrections.md) sous la main.

> 💡 Sans pré-téléchargement, le Lab 6 (ZAP, 3,7 Go) peut saturer le réseau de la salle. **À faire la veille.**

---

## 🎚️ Plans B selon le temps restant

- **En retard ?** Les Labs 3 et 4 peuvent être fusionnés (même outil, Trivy). Le Lab 5 (IaC) peut passer en démo. **Ne sacrifiez jamais les Labs 2 et 7** (le cœur pédagogique).
- **En avance ?** Approfondissez le Lab 7 (plus de challenges du Score Board) ou lancez le `zap-full-scan` (actif) en démo.
- **Groupe très à l'aise ?** Faites-leur écrire une **règle Semgrep custom** ou corriger réellement une faille + relancer le scan pour la voir disparaître.
