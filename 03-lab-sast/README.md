# Lab 2 — Analyse statique du code (SAST) avec Semgrep

⏱️ **60 minutes** · 🧩 Difficulté : ⭐⭐ · 🎯 Objectif : trouver des failles **dans le code source** sans exécuter l'application, et localiser précisément la ligne à corriger

📍 **Où dans la chaîne ?** À l'étape **build / analyse de code**, juste après le commit.

```
CODE ─► Secrets ─► [🔒 SAST] ─► SCA ─► Conteneur ─► IaC ─► DAST
                    Semgrep
                   ◄── vous êtes ici
```

---

## 2.1 — SAST : lire le code comme un relecteur expert

**SAST** = *Static Application Security Testing*. On analyse le **code source** (statique = sans le lancer), à la recherche de motifs dangereux.

Analogie : c'est comme **relire une recette de cuisine** pour repérer les erreurs (« ajouter de l'eau de javel » 🧨) *avant* de cuisiner, plutôt que de goûter le plat fini.

**Forces** 👍
- Détecte la faille **exactement à la ligne** de code → le dev sait quoi corriger.
- Très tôt dans le cycle (shift-left maximal).
- Couvre des chemins de code même rarement exécutés.

**Limites** 👎
- **Faux positifs** : le code *semble* vulnérable mais ne l'est pas dans le contexte réel.
- Ne sait pas si la faille est réellement **atteignable/exploitable** (c'est le rôle du DAST, Lab 6).

---

## 2.2 — L'outil : Semgrep

**Semgrep** (« semantic grep ») cherche des **motifs** dans le code, façon « rechercher-remplacer » mais qui *comprend* la structure du langage. Ses règles sont regroupées en **rulesets** publics (`p/…`), par exemple :

- `p/owasp-top-ten` — les failles du Top 10 OWASP,
- `p/javascript`, `p/typescript`, `p/nodejs` — spécifiques au langage/écosystème.

---

## 2.3 — Lancer le scan

Placez-vous à la racine du dépôt Juice Shop :

```bash
cd ~/juice-shop   # ← la racine de VOTRE clone Juice Shop (adaptez le chemin)
```

Scannez le code **serveur** (on cible les dossiers à risque et on exclut le bruit) :

```bash
semgrep scan \
  --config p/javascript --config p/typescript --config p/nodejs \
  --exclude test --exclude data/static/codefixes --exclude frontend/src/assets \
  --metrics=off \
  routes lib server.ts app.ts models
```

| Option | Rôle |
|--------|------|
| `--config p/...` | Les paquets de règles à utiliser |
| `--exclude test` | On ignore les tests (bruit) |
| `--exclude data/static/codefixes` | Juice Shop y stocke des exemples de code **volontairement** vulnérables/corrigés |
| `--metrics=off` | Pas d'envoi de télémétrie |
| `routes lib …` | Les dossiers du code serveur à analyser |

> 💡 **Note formateur** : le **premier** lancement télécharge les règles (quelques secondes) et l'analyse prend ~2-4 min sur cette machine. Lancez-le, puis commentez pendant que ça tourne.

À la fin, Semgrep affiche un **résumé** puis le détail. On s'attend à ~**9 findings**, dont deux marqués `ERROR` (haute sévérité).

---

## 2.4 — Les résultats, triés par gravité

Voici ce que Semgrep remonte (fichier : ligne → règle) :

| Sévérité | Fichier:ligne | Règle | Type de faille (OWASP) |
|----------|---------------|-------|------------------------|
| 🔴 ERROR | `routes/login.ts:34` | `express-sequelize-injection` | **Injection SQL** (A03) |
| 🔴 ERROR | `routes/search.ts:23` | `express-sequelize-injection` | **Injection SQL** (A03) |
| 🔴 ERROR | `routes/userProfile.ts:65` | `code-string-concat` | **Injection de code** (`eval`) (A03) |
| 🟠 WARNING | `routes/redirect.ts:18` | `express-open-redirect` | **Redirection ouverte** (A01) |
| 🟠 WARNING | `lib/insecurity.ts:54` | `hardcoded-jwt-secret` | **Secret en dur** (A02/A05) |
| 🟠 WARNING | `routes/fileServer.ts` … (×4) | `express-res-sendfile` | **Path traversal potentiel** (A01) |

> 🎯 On **priorise par sévérité** : les 3 `ERROR` d'abord. Et regardez `routes/login.ts:34` — **c'est exactement la faille qu'on a exploitée en démo ce matin** (le `' OR 1=1--`). On va maintenant la voir dans le code.

---

## 2.5 — Zoom sur l'injection SQL (`login.ts:34`)

Ciblons cette règle précise pour ne voir que ça :

```bash
semgrep scan --config p/nodejs --metrics=off routes/login.ts
```

Semgrep pointe la ligne 34. Ouvrez-la :

```bash
sed -n '34p' routes/login.ts
```

```ts
models.sequelize.query(`SELECT * FROM Users WHERE email = '${req.body.email || ''}' AND password = '${security.hash(req.body.password || '')}' AND deletedAt IS NULL`, ...)
```

### 🔍 Pourquoi c'est vulnérable ?

La donnée envoyée par l'utilisateur (`req.body.email`) est **collée directement** dans la requête SQL via une *template string* (`${...}`). L'utilisateur contrôle donc une partie de la requête !

Si j'envoie comme email :  `' OR 1=1--`  la requête devient :

```sql
SELECT * FROM Users WHERE email = '' OR 1=1--' AND password = '...' AND deletedAt IS NULL
```

- `OR 1=1` → toujours vrai → renvoie **tous** les utilisateurs (le premier = l'admin).
- `--` → commente le reste (la vérification du mot de passe **saute**).

➡️ **Connexion en admin sans mot de passe.** On l'exploitera en détail au [Lab 7](../08-lab-exploitation/README.md).

> 💡 **Note formateur** : faites le parallèle immédiat avec la démo du matin. « Le scanner a trouvé *en 2 minutes*, dans 400 fichiers, la ligne exacte qu'on a exploitée. Voilà la valeur du SAST. »

---

## 2.6 — Comment corriger ? (la requête paramétrée)

La règle absolue contre l'injection SQL : **ne jamais concaténer** de donnée utilisateur dans une requête. On utilise des **requêtes paramétrées** (*prepared statements*) : la donnée est passée **à part**, jamais interprétée comme du code SQL.

Juice Shop fournit la version corrigée. Comparez :

```bash
sed -n '15,17p' data/static/codefixes/loginAdminChallenge_4_correct.ts
```

```ts
// ✅ CORRECT — la donnée passe par des paramètres $1, $2
models.sequelize.query(
  `SELECT * FROM Users WHERE email = $1 AND password = $2 AND deletedAt IS NULL`,
  { replacements: [ req.body.email, security.hash(req.body.password) ], ... }
)
```

| ❌ Vulnérable | ✅ Corrigé |
|--------------|-----------|
| `WHERE email = '${req.body.email}'` | `WHERE email = $1` + `replacements: [...]` |
| La donnée devient du **code** | La donnée reste une **valeur** |

> 🎯 **Ce qu'il faut retenir** : *données ≠ code*. Toute la sécurité applicative tourne autour de cette séparation (injection SQL, XSS, injection de commandes… même combat).

---

## 2.7 — Exercice : enquêter sur une autre faille

> ✋ **À vous de jouer** (15 min) : choisissez **une** des failles ci-dessous, ouvrez le code, et répondez à : *(1) quelle donnée l'utilisateur contrôle-t-il ? (2) que peut-il en faire ? (3) comment corriger ?*

**Option A — Injection de code (`userProfile.ts:65`)**
```bash
sed -n '60,68p' routes/userProfile.ts
```
<details><summary>Indice</summary>
La ligne `username = eval(code)` exécute comme **code JavaScript** une partie du nom d'utilisateur. Un attaquant peut donc faire tourner son propre code sur le serveur (**SSTI / RCE**). Correction : bannir `eval()` — il n'y a presque jamais de raison légitime de l'utiliser.
</details>

**Option B — Redirection ouverte (`redirect.ts:18`)**
```bash
sed -n '14,22p' routes/redirect.ts
```
<details><summary>Indice</summary>
Le paramètre `?to=` contrôle la cible d'une redirection. Mal filtré, un attaquant fabrique un lien `.../redirect?to=https://site-pirate.com` qui *paraît* venir de Juice Shop → **hameçonnage**. Correction : n'autoriser qu'une **liste blanche** stricte de destinations.
</details>

**Option C — Secret en dur (`insecurity.ts:54`)**
```bash
sed -n '52,56p' lib/insecurity.ts
```
<details><summary>Indice</summary>
La clé de signature JWT est écrite dans le code (on l'a déjà vue au Lab 1 !). SAST et secret scanning se **recoupent** ici : deux outils, une même faille. Correction : charger la clé depuis un **coffre** / variable d'environnement.
</details>

---

## 2.8 — Générer un rapport pour la CI (format SARIF)

En pipeline, on veut un rapport standard que les plateformes (GitHub, GitLab) savent afficher : le **SARIF**.

```bash
semgrep scan --config p/javascript --config p/typescript \
  --exclude test --exclude data/static/codefixes \
  --sarif --output semgrep.sarif --metrics=off \
  routes lib
```

> 💡 Le fichier `semgrep.sarif` peut être **importé dans l'onglet Security de GitHub** : chaque finding devient une alerte annotée directement sur la ligne de code de la Pull Request. On branchera ça au [Lab 8](../09-lab-pipeline/README.md).

---

## ✅ Checklist de fin de lab

- [ ] J'ai lancé Semgrep et obtenu ~9 findings.
- [ ] J'ai trouvé l'injection SQL en `login.ts:34` et je sais **pourquoi** elle est exploitable.
- [ ] Je sais expliquer la correction par **requête paramétrée**.
- [ ] J'ai enquêté sur une 2ᵉ faille (eval / open-redirect / secret).
- [ ] J'ai généré un rapport SARIF.

> 🎯 **SAST = trouver la ligne exacte, tôt.** Mais il ne dit pas si c'est *vraiment* exploitable → c'est ce que confirmeront le DAST (Lab 6) et l'exploitation manuelle (Lab 7).

➡️ **Lab suivant : [Lab 3 — Dépendances vulnérables (SCA)](../04-lab-sca/README.md)**
