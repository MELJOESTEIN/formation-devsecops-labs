# 📖 Glossaire DevSecOps

Tous les termes et acronymes de la journée, expliqués simplement.

---

## Les grandes familles d'outils

| Terme | Développé | En français simple |
|-------|-----------|--------------------|
| **DevSecOps** | Development + Security + Operations | Intégrer la sécurité **partout** dans la chaîne de développement, automatiquement. |
| **SAST** | Static Application Security Testing | Analyser le **code source** sans l'exécuter. (Lab 2) |
| **DAST** | Dynamic Application Security Testing | Attaquer l'**application en marche**. (Lab 6) |
| **SCA** | Software Composition Analysis | Vérifier les **bibliothèques tierces** (dépendances). (Lab 3) |
| **IaC Scanning** | Infrastructure as Code Scanning | Vérifier les fichiers d'**infrastructure** (Terraform…). (Lab 5) |
| **Secret Scanning** | — | Chercher les **mots de passe/clés** oubliés dans le code. (Lab 1) |
| **IAST / RASP** | Interactive / Runtime … | Analyse *pendant* l'exécution réelle (niveau avancé, hors formation). |

---

## Concepts clés

| Terme | Explication |
|-------|-------------|
| **Shift Left** | Détecter les problèmes **le plus tôt possible** dans le cycle (à gauche = tôt). Moins cher à corriger. |
| **Security Gate** | Un point de contrôle du pipeline qui **bloque** la livraison si une faille grave est trouvée. |
| **Fail Fast** | Faire échouer le pipeline **au plus tôt** pour un retour rapide au développeur. |
| **CI/CD** | Continuous Integration / Continuous Delivery : automatiser build, test et déploiement à chaque changement. |
| **Pipeline** | La suite d'étapes automatiques déclenchées par un `git push`. |
| **False Positive** (faux positif) | Une alerte qui **n'est pas** une vraie faille. Le tri (*triage*) est un travail humain essentiel. |
| **True Positive** (vrai positif) | Une alerte qui correspond à une **vraie** faille. |
| **Triage** | Trier et prioriser les alertes (vraie faille ? gravité ? exploitable ?). |
| **Defense in Depth** | Plusieurs couches de défense qui se recoupent, pour qu'une faille seule ne suffise pas. |
| **Least Privilege** (moindre privilège) | Ne donner que les droits strictement nécessaires (au code, aux utilisateurs, aux jobs CI). |
| **Supply Chain** (chaîne d'appro.) | L'ensemble des dépendances et outils tiers dont dépend votre logiciel. Cible d'attaques majeures. |

---

## Vulnérabilités & sécurité

| Terme | Explication |
|-------|-------------|
| **Vulnérabilité** | Une faiblesse exploitable dans un système. |
| **Exploit** | Le fait (ou le code) d'**utiliser** une vulnérabilité. |
| **CVE** | Common Vulnerabilities and Exposures : l'**identifiant public** unique d'une faille connue (ex. CVE-2019-10744). |
| **CVSS** | Le **score de gravité** d'une CVE (0 à 10). ≥ 9 = Critical. |
| **CWE** | Common Weakness Enumeration : la **catégorie** de faiblesse (ex. CWE-89 = injection SQL). |
| **OWASP** | Open Worldwide Application Security Project : l'organisation de référence en sécu web. |
| **OWASP Top 10** | Le classement des 10 risques web les plus critiques (A01 à A10). |
| **Injection SQL** | Injecter du SQL via une saisie utilisateur pour manipuler la base. (A03, Labs 2 & 7) |
| **XSS** | Cross-Site Scripting : injecter du JavaScript exécuté dans le navigateur des victimes. (A03, Lab 7) |
| **CSRF** | Cross-Site Request Forgery : forcer un utilisateur à exécuter une action à son insu. |
| **Broken Access Control** | Contrôles d'accès défaillants (accès à ce qu'on ne devrait pas). (A01, Lab 7) |
| **SSTI / RCE** | Server-Side Template Injection / Remote Code Execution : exécuter son code sur le serveur. (Lab 2 §2.7) |
| **Open Redirect** | Redirection non contrôlée servant à l'hameçonnage. (Lab 2 §2.7) |
| **Prototype Pollution** | Faille JS où l'on corrompt les objets de base (ex. CVE lodash). |

---

## Outils & formats

| Terme | Explication |
|-------|-------------|
| **Gitleaks** | Scanner de secrets. (Lab 1) |
| **Semgrep** | Scanner SAST par motifs sémantiques. (Lab 2) |
| **Trivy** | Scanner tout-en-un : dépendances, images, IaC. (Labs 3-4-5) |
| **OWASP ZAP** | Scanner DAST (proxy d'attaque web). (Lab 6) |
| **SBOM** | Software Bill of Materials : la « liste des ingrédients » d'un logiciel (ses composants). |
| **SARIF** | Format standard de rapport de sécurité, lisible par GitHub/GitLab. |
| **CycloneDX / SPDX** | Deux formats standard de SBOM. |
| **Requête paramétrée** | Requête SQL où la donnée est passée **séparément** du code → contre l'injection SQL. |
| **Hash / MD5 / bcrypt** | Empreinte d'un mot de passe. MD5 = **cassé** ; bcrypt/argon2 = recommandés. |
| **JWT** | JSON Web Token : jeton de session signé. Vulnérable si la **clé de signature** fuite. (Lab 7 §7.5) |
| **Distroless** | Image Docker minimale (sans shell ni gestionnaire de paquets) → surface d'attaque réduite. |
