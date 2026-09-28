# Lab 1 — Chasse aux secrets avec Gitleaks

⏱️ **45 minutes** · 🧩 Difficulté : ⭐ · 🎯 Objectif : détecter les secrets codés en dur dans le dépôt et comprendre pourquoi c'est dangereux

📍 **Où dans la chaîne ?** Tout à gauche : **au commit**. C'est la première barrière, la plus « shift-left » possible.

```
CODE ─► [🔒 SECRETS] ─► SAST ─► SCA ─► Conteneur ─► IaC ─► DAST
         Gitleaks
        ◄── vous êtes ici
```

---

## 1.1 — C'est quoi un « secret » et pourquoi c'est grave ?

Un **secret**, c'est toute donnée d'authentification qui ne devrait *jamais* être publique :

- mots de passe, clés d'API (AWS, Stripe, Google…),
- **clés privées** (SSH, TLS, RSA),
- jetons (JWT, tokens d'accès), chaînes de connexion à une base de données.

**Le problème** : quand un secret est écrit « en dur » dans le code et *commité* dans Git, il reste dans **l'historique du dépôt pour toujours** — même si vous le supprimez dans un commit ultérieur. Si le dépôt fuite (open source par erreur, employé malveillant, fuite GitHub), l'attaquant récupère les clés.

> 💡 **Note formateur** — chiffre marquant : des scanners publics trouvent en continu des **millions** de secrets sur GitHub. Une clé AWS fuitée peut être exploitée en **quelques minutes** par des bots pour miner de la crypto sur votre compte (facture à 5 chiffres).

> 🎯 Règle d'or : **un secret ne doit jamais entrer dans Git.** Il vit dans un coffre (Vault, secrets du CI, variables d'environnement), jamais dans le code.

---

## 1.2 — L'outil : Gitleaks

**Gitleaks** est un scanner de secrets. Il parcourt les fichiers (ou tout l'historique Git) et repère ce qui *ressemble* à un secret, grâce à :

- des **expressions régulières** (motifs de clés AWS, Google, etc.),
- une mesure d'**entropie** (une chaîne « aléatoire » a de fortes chances d'être une clé).

---

## 1.3 — Premier scan

Placez-vous à la **racine du dépôt Juice Shop** (le dossier parent de `formation-devsecops/`) :

```bash
cd ~/juice-shop   # ← la racine de VOTRE clone Juice Shop (adaptez le chemin)
```

Lancez le scan du répertoire :

```bash
gitleaks dir . --no-banner --redact --report-format json --report-path gitleaks-rapport.json
```

| Option | Rôle |
|--------|------|
| `dir .` | Scanner le contenu du dossier courant |
| `--no-banner` | Pas de logo ASCII (sortie plus propre) |
| `--redact` | **Masquer** la valeur des secrets dans l'affichage (bonne habitude : on ne recopie pas un secret dans un rapport !) |
| `--report-format json` | Générer un rapport exploitable par machine |
| `--report-path` | Où écrire le rapport |

À la fin, Gitleaks affiche quelque chose comme :

```
WRN leaks found: 69
```

> 💡 Le nombre exact peut varier légèrement selon la version. L'important : **il y en a des dizaines**.

---

## 1.4 — Lire le rapport

Comptons les fuites par type :

```bash
python3 -c "
import json, collections
d = json.load(open('gitleaks-rapport.json'))
print('Total :', len(d))
for rule, n in collections.Counter(x['RuleID'] for x in d).most_common():
    print(f'  {n:3}  {rule}')
"
```

Résultat attendu (ordre de grandeur) :

```
Total : 69
   54  generic-api-key
   12  jwt
    3  private-key
```

Trois familles :

- **`private-key`** 🔴 — le plus grave : des **clés privées RSA** en clair.
- **`jwt`** 🟠 — des jetons de session JSON Web Token.
- **`generic-api-key`** 🟡 — des chaînes ressemblant à des clés/mots de passe (beaucoup sont dans les fichiers de test → potentiels **faux positifs**, on y revient).

---

## 1.5 — La trouvaille la plus grave : une clé privée RSA

Regardons où sont les clés privées :

```bash
python3 -c "
import json
d = json.load(open('gitleaks-rapport.json'))
for x in d:
    if x['RuleID'] == 'private-key':
        print(x['File'], 'ligne', x['StartLine'])
"
```

Vous obtenez notamment :

```
lib/insecurity.ts ligne 21
terraform/networking.tf ligne 171
```

Ouvrez le fichier incriminé :

```bash
sed -n '20,22p' lib/insecurity.ts
```

Vous voyez une **clé privée RSA complète, en clair, dans le code source** :

```ts
const privateKey = '-----BEGIN RSA PRIVATE KEY-----\r\nMIICXAIBAAKBgQ...'
```

> ⚠️ **C'est catastrophique.** Cette clé privée sert à **signer les jetons JWT** de l'application (voir `lib/insecurity.ts`, fonction `authorize`). Quiconque possède cette clé peut **forger un jeton valide pour n'importe quel utilisateur, y compris l'admin**. On exploitera exactement ça au **[Lab 7](../08-lab-exploitation/README.md)** (challenge *« Forged Signed JWT »*).

> 🎯 **Le lien SAST ↔ exploitation** : ici on *voit* le secret dans le code (shift-left). Au Lab 7, on *l'utilise* pour prendre le contrôle. C'est toute la logique de la journée.

---

## 1.6 — Vrais positifs vs faux positifs

> ✋ **À vous de jouer** (10 min) : parmi les 69 résultats, tous ne sont pas des vraies fuites. Ouvrez 3 fichiers signalés et classez-les.

Regardons les fichiers les plus signalés :

```bash
python3 -c "
import json, collections
d = json.load(open('gitleaks-rapport.json'))
for f, n in collections.Counter(x['File'] for x in d).most_common(8):
    print(f'  {n:3}  {f}')
"
```

Vous verrez beaucoup de `test/api/*.test.ts`. **Question** : un mot de passe dans un fichier de test, est-ce une vraie fuite ?

<details>
<summary>👉 Réponse</summary>

**Ça dépend, et c'est là tout le métier.**

- `lib/insecurity.ts` (clé privée RSA) → **VRAI POSITIF** 🔴. Une vraie clé de signature dans le code applicatif.
- `terraform/networking.tf` (clé privée) → **VRAI POSITIF** 🔴 (secret dans de l'IaC = classique et grave).
- `test/api/login.test.ts` (mots de passe) → souvent **FAUX POSITIF** 🟡 : ce sont des identifiants *de test*, connus et sans valeur… **MAIS** parfois un·e dev colle un vrai mot de passe « juste pour tester ». À vérifier au cas par cas.

**Leçon DevSecOps** : un scanner **propose**, l'humain **décide**. Le tri (*triage*) des résultats est une compétence clé. On ne « corrige » pas aveuglément 69 alertes : on **priorise** (les clés privées d'abord) et on **documente** les faux positifs pour ne plus être alerté dessus.

</details>

---

## 1.7 — Réduire le bruit : l'allowlist

Pour qu'un faux positif ne réapparaisse pas à chaque scan, on l'ajoute à une **liste d'autorisation** (`.gitleaks.toml`). Créez ce fichier à la racine :

```bash
cat > .gitleaks.toml <<'EOF'
title = "Config Gitleaks - Formation DevSecOps"

[extend]
useDefault = true   # on garde toutes les règles par défaut

[allowlist]
description = "Chemins de test connus (identifiants factices)"
paths = [
  '''test/api/.*\.test\.ts''',
  '''test/cypress/.*\.spec\.ts''',
]
EOF
```

Relancez le scan **avec** cette config :

```bash
gitleaks dir . --no-banner --redact -c .gitleaks.toml
```

> 💡 Le nombre de fuites **diminue** : on a filtré le bruit des tests. Les vraies fuites (clés privées) restent. C'est ça, **régler la sensibilité d'un outil** pour qu'il soit utilisable au quotidien sans noyer les devs sous les alertes.

> ⚠️ **Attention** : une allowlist trop large **cache de vraies failles**. On n'exclut jamais un dossier « pour avoir la paix ». On justifie chaque exclusion.

---

## 1.8 — En conditions réelles : le pre-commit hook

L'idéal du *shift-left* : **bloquer le secret avant même le commit**, sur le poste du dev. Gitleaks s'installe en *hook* Git :

```bash
gitleaks git --pre-commit   # (démonstration du principe)
```

En pratique on utilise le framework [`pre-commit`](https://pre-commit.com/). Exemple de `.pre-commit-config.yaml` :

```yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks
```

Désormais, `git commit` **échoue** si un secret est détecté → le dev corrige *avant* que le secret n'entre dans l'historique. **Coût de correction : quasi nul.** C'est le shift-left poussé au maximum.

---

## ✅ Checklist de fin de lab

- [ ] J'ai lancé Gitleaks et obtenu ~69 fuites.
- [ ] J'ai identifié la **clé privée RSA** dans `lib/insecurity.ts` comme la plus grave.
- [ ] Je sais distinguer un vrai positif d'un faux positif (test vs code applicatif).
- [ ] J'ai créé une `.gitleaks.toml` avec une allowlist justifiée.
- [ ] Je comprends l'intérêt d'un hook pre-commit.

> 🎯 **Ce qu'il faut retenir** : les secrets n'ont **rien à faire** dans Git. On les détecte au plus tôt (pre-commit / CI), on trie humainement, et on les stocke dans un coffre.

➡️ **Lab suivant : [Lab 2 — Analyse statique (SAST) avec Semgrep](../03-lab-sast/README.md)**
