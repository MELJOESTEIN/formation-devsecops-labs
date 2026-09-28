# Lab 5 — Infrastructure as Code (IaC) avec Trivy

⏱️ **30 minutes** · 🧩 Difficulté : ⭐⭐ · 🎯 Objectif : détecter les mauvaises configurations dans du Terraform **avant** de créer l'infrastructure

📍 **Où dans la chaîne ?** Étape **provisioning / déploiement de l'infra**.

```
CODE ─► Secrets ─► SAST ─► SCA ─► Conteneur ─► [🔒 IaC] ─► DAST
                                                Trivy config
                                               ◄── vous êtes ici
```

---

## 5.1 — Quand l'infrastructure devient du code

Avant, on configurait les serveurs **à la main** (clic dans une console cloud). Aujourd'hui, on décrit l'infrastructure dans des **fichiers** : c'est l'**Infrastructure as Code** (Terraform, CloudFormation, Kubernetes YAML, Ansible…).

**Avantage** : reproductible, versionné, revu en équipe.
**Nouveau risque** : une **erreur de config** (un port ouvert à tout Internet, un bucket S3 public, du HTTP au lieu de HTTPS) est maintenant **répliquée automatiquement** à chaque déploiement. Une faute de frappe = une faille en production, partout.

Bonne nouvelle : puisque c'est du code, on peut le **scanner** avant de l'appliquer. C'est le *shift-left* appliqué à l'infra.

> ⚠️ **Rappel important** : les fichiers `infrastructure/` et `terraform/` de Juice Shop sont **volontairement non sécurisés** et font partie des challenges. **On ne les déploie JAMAIS.** On les utilise ici comme cas d'école.

---

## 5.2 — Scanner le Terraform

```bash
cd ~/juice-shop   # ← la racine de VOTRE clone Juice Shop (adaptez le chemin)
trivy config --severity CRITICAL,HIGH infrastructure
```

Résultat (réel) : **8 mauvaises configurations** (4 CRITICAL + 4 HIGH), toutes dans `terraform/networking.tf`.

---

## 5.3 — Lire et comprendre chaque alerte

| Sévérité | ID | Ligne | Problème | Risque concret |
|----------|-----|-------|----------|----------------|
| 🔴 CRITICAL | AWS-0054 | 157 | **HTTP en clair** (pas de HTTPS) | Le trafic (mots de passe, jetons) circule **non chiffré** → interception |
| 🔴 CRITICAL | AWS-0104 | 86, 112, 239 | **Sortie réseau illimitée** (egress `0.0.0.0/0`) | Une machine compromise peut **exfiltrer** des données n'importe où |
| 🟠 HIGH | AWS-0053 | 124 | Load balancer **exposé à Internet** | Surface d'attaque publique |
| 🟠 HIGH | AWS-0052 | 122 | LB n'écarte pas les **en-têtes invalides** | Contournement de sécurité / *request smuggling* |
| 🟠 HIGH | AWS-0164 | 23 | Sous-réseau attribuant une **IP publique par défaut** | Des ressources exposées sans le vouloir |

Regardons la plus parlante — le HTTP en clair (AWS-0054) :

```bash
sed -n '150,160p' infrastructure/terraform/networking.tf
```

Vous verrez un *listener* sur le **port 80 en HTTP**. En clair : les identifiants des clients de Juice Shop transiteraient **sans chiffrement**.

> 🎯 **Ce qu'il faut retenir** : ces failles n'ont **rien à voir avec le code applicatif**. L'app pourrait être parfaite : une infra mal configurée l'expose quand même. La sécurité, c'est **toute la chaîne**.

---

## 5.4 — Bonus : un secret dans l'IaC (recoupement avec le Lab 1)

Souvenez-vous : au **Lab 1**, Gitleaks avait signalé une clé privée dans `terraform/networking.tf`. Retrouvons-la :

```bash
grep -n "BEGIN RSA PRIVATE KEY" infrastructure/terraform/networking.tf
```

```bash
sed -n '168,172p' infrastructure/terraform/networking.tf
```

Une **clé privée TLS est codée en dur** dans la ressource `aws_iam_server_certificate` ! C'est le challenge *« Leaked Access Logs »* / *« Infrastructure as Code »* de Juice Shop.

> 💡 **Deux outils, deux angles, une même faille** : Gitleaks l'a vue en tant que *secret*, Trivy la verrait aussi dans une analyse plus large. Les couches de défense se **recoupent** — c'est voulu (*defense in depth*).

**Correction** : une clé privée ne se met **jamais** dans un fichier Terraform. On la stocke dans un gestionnaire de secrets (AWS Secrets Manager, HashiCorp Vault) et on y **référence** via une *data source*.

---

## 5.5 — Faire bloquer le pipeline

Comme pour les conteneurs, on veut que le CI **refuse** un Terraform mal configuré :

```bash
trivy config --severity CRITICAL,HIGH --exit-code 1 infrastructure
```

`--exit-code 1` → le pipeline échoue tant qu'il reste des misconfigs critiques. Le déploiement est **bloqué avant** de toucher au cloud.

> ✋ **À vous de jouer** : d'après vous, faut-il bloquer sur **HIGH** aussi, ou seulement **CRITICAL** ? Discutez-en. (Réponse : ça dépend de la **maturité** de l'équipe — on commence souvent par bloquer sur CRITICAL, puis on resserre. L'important est de **ne pas tout bloquer d'un coup** au risque de braquer les équipes.)

---

## ✅ Checklist de fin de lab

- [ ] J'ai scanné le Terraform et trouvé **8 misconfigs** (4 critiques).
- [ ] Je sais expliquer le risque du **HTTP en clair** et de l'**egress illimité**.
- [ ] J'ai retrouvé la **clé privée en dur** dans le `.tf` (lien avec le Lab 1).
- [ ] Je sais bloquer un déploiement avec `--exit-code 1`.
- [ ] Je n'utiliserai **jamais** ces fichiers pour un vrai déploiement. 😉

➡️ **Lab suivant : [Lab 6 — Analyse dynamique (DAST) avec OWASP ZAP](../07-lab-dast/README.md)**
