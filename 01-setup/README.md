# Lab 0 — Mise en place de l'environnement

⏱️ **30 minutes** · 🧩 Difficulté : ⭐ (très facile) · 🎯 Objectif : avoir Juice Shop qui tourne + tous les outils prêts

---

## Ce qu'on va faire

1. Vérifier que les outils de sécurité sont installés.
2. Démarrer OWASP Juice Shop dans Docker.
3. Explorer l'application et **trouver le tableau des scores caché** (premier challenge !).

> 💡 **Note formateur** : c'est le moment de débloquer les problèmes d'environnement. Faites-le tous ensemble. Personne ne passe au Lab 1 tant que `http://localhost:3000` ne s'affiche pas.

---

## Étape 1 — Vérifier les outils

Ouvrez un terminal et lancez ces commandes une par une. Chacune doit afficher un numéro de version (peu importe lequel) :

```bash
docker --version      # ex: Docker version 29.x
node --version        # ex: v24.x
gitleaks version      # ex: 8.x
semgrep --version     # ex: 1.x
trivy --version       # ex: Version: 0.74.x
git --version         # ex: git version 2.x
```

> ⚠️ **Attention** : si l'une des commandes renvoie *« command not found »*, signalez-le au formateur **maintenant**. On corrige avant d'avancer.

### Raccourci

Le dépôt fournit un script qui vérifie tout **et** démarre l'application :

```bash
cd formation-devsecops
./scripts/setup.sh
```

Si le script se termine par *« Environnement prêt ! 🧃 »*, vous pouvez sauter à l'**Étape 4**. Sinon, suivez les étapes 2 et 3 à la main pour comprendre ce qui se passe.

---

## Étape 2 — Récupérer l'image Docker de Juice Shop

Une **image Docker** est un « paquet » figé contenant l'application et tout ce qu'il lui faut pour tourner. On la télécharge une fois :

```bash
docker pull bkimminich/juice-shop:v20.2.0
```

> 💡 On épingle la version `v20.2.0` (au lieu de `latest`) pour que **tout le monde ait exactement la même chose**. Épingler les versions est déjà une bonne pratique DevSecOps : on veut des builds **reproductibles**.

---

## Étape 3 — Démarrer l'application

```bash
docker run -d --name juice-shop -p 3000:3000 bkimminich/juice-shop:v20.2.0
```

Décortiquons cette commande, car on la réutilisera :

| Morceau | Signification |
|---------|---------------|
| `docker run` | Créer et lancer un conteneur |
| `-d` | En arrière-plan (*detached*), le terminal reste libre |
| `--name juice-shop` | On donne un nom au conteneur pour le retrouver facilement |
| `-p 3000:3000` | On expose le port 3000 du conteneur sur le port 3000 de la machine |
| `bkimminich/juice-shop:v20.2.0` | L'image à lancer |

Vérifiez que le conteneur tourne :

```bash
docker ps
```

Vous devez voir une ligne `juice-shop` avec le statut `Up`.

L'app met **10 à 20 secondes** à démarrer. Suivez le démarrage :

```bash
docker logs -f juice-shop
```

Attendez la ligne `info: Server listening on port 3000`, puis quittez avec `Ctrl+C` (ça n'arrête **pas** le conteneur, juste l'affichage des logs).

> 💡 **Note formateur** : vous verrez des `warn` sur `localhost:11434` (l'API du chatbot LLM). C'est **normal**, on n'utilise pas les challenges LLM aujourd'hui.

---

## Étape 4 — Ouvrir Juice Shop

Ouvrez votre navigateur sur : **[http://localhost:3000](http://localhost:3000)**

Vous devez voir la boutique de jus de fruits. 🧃 Cliquez, baladez-vous : ajoutez un produit au panier, ouvrez un produit…

> ⚠️ Fermez le bandeau *« Welcome »* et la fenêtre des cookies (« Me too ») pour dégager la vue.

---

## Étape 5 — Premier challenge : trouver le tableau des scores 🏆

Juice Shop suit votre progression sur une page **volontairement cachée** : le **Score Board**. Le premier défi est… de la trouver.

> ✋ **À vous de jouer** (5 min) : essayez de trouver l'URL du tableau des scores **sans regarder la solution ci-dessous**.
>
> *Indice : les applications web ont souvent des pages « techniques » à des URLs devinables. Essayez d'ajouter des mots après `http://localhost:3000/#/`…*

<details>
<summary>👉 Cliquez pour la solution</summary>

Rendez-vous sur : **[http://localhost:3000/#/score-board](http://localhost:3000/#/score-board)**

Vous venez de résoudre votre premier challenge : *« Score Board »* ! 🎉

La page liste **tous les challenges** classés par difficulté (⭐ à ⭐⭐⭐⭐⭐⭐) et par catégorie OWASP. C'est votre **tableau de bord** pour le reste de la journée : chaque fois que vous exploiterez une faille, le challenge correspondant passera au **vert**.

> **Comment on l'a trouvée ?** En réfléchissant comme un attaquant : les développeurs nomment souvent leurs pages de façon logique (`score-board`, `admin`, `metrics`…). On teste les URLs « évidentes ». C'est de l'**énumération**, une technique de reconnaissance de base.

</details>

---

## Étape 6 — Repérer la version (reconnaissance)

Un attaquant commence toujours par identifier **quelle version** tourne, pour chercher les failles connues. Juice Shop expose la sienne :

```bash
curl -s http://localhost:3000/rest/admin/application-version
```

> 🎯 **Ce qu'il faut retenir** : connaître la version exacte d'un logiciel permet de chercher ses CVE (failles publiques connues). C'est pour ça qu'on **cache** les versions en production — ici Juice Shop la donne volontairement.

---

## ✅ Checklist de fin de lab

- [ ] Tous les outils répondent à `--version`.
- [ ] `docker ps` montre `juice-shop` en statut `Up`.
- [ ] `http://localhost:3000` affiche la boutique.
- [ ] J'ai trouvé et ouvert le **Score Board** (`/#/score-board`).

### 🆘 Dépannage rapide

| Problème | Solution |
|----------|----------|
| `port is already allocated` | Un autre service occupe le 3000. Utilisez `-p 3001:3000` puis allez sur `:3001`. |
| La page ne charge pas | Attendez 20 s de plus, puis `docker logs juice-shop`. Cherchez `Server listening`. |
| Je veux repartir de zéro | `docker rm -f juice-shop` puis relancez l'Étape 3. |
| `permission denied` sur Docker | Votre utilisateur n'est pas dans le groupe `docker`. Préfixez par `sudo` ou voir le formateur. |

➡️ **Lab suivant : [Lab 1 — Chasse aux secrets avec Gitleaks](../02-lab-secrets/README.md)**
