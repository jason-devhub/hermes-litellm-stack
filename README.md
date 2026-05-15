# Hermes + LiteLLM + NVIDIA API (Minimax)

Installation simple de Hermes AI avec :
- LiteLLM
- NVIDIA API

---

# Architecture

Hermes
↓
LiteLLM
↓
NVIDIA API

---

# Hermes (image officielle)

Ce dépôt utilise l’image **`nousresearch/hermes-agent`** avec la commande **`gateway run`** et les données sous **`/opt/data`** ([guide Docker](https://hermes-agent.nousresearch.com/docs/user-guide/docker)). Sur Coolify, Hermes est construit via `Dockerfile.hermes` pour embarquer `hermes-config.yaml` dans l’image au lieu de le monter comme fichier sous `/opt/data/config.yaml`.

LiteLLM utilise une petite image locale construite par `Dockerfile.litellm` : base Python, installation de `litellm[proxy]`, puis copie de `litellm-config.yaml` vers `/app/proxy_server_config.yaml`. C’est plus fiable sur Coolify qu’un bind mount de fichier et cela évite de retomber sur la config Azure d’exemple embarquée dans certaines images LiteLLM.

---

# Deux fichiers YAML : pourquoi on ne fusionne pas

| Fichier | Lu par | Rôle |
| --- | --- | --- |
| **`litellm-config.yaml`** | LiteLLM | Liste des modèles (`model_list`), alias (`fast-model`), `api_base`, clés via `os.environ/…`. Schéma [doc LiteLLM proxy](https://docs.litellm.ai/docs/proxy/configs). |
| **`hermes-config.yaml`** | Hermes | Bloc **`model:`** au [format Hermes](https://hermes-agent.nousresearch.com/docs/integrations/providers#custom--self-hosted-llm-providers) (`provider`, `default`, `context_length`, …). Ce n’est **pas** le même schéma que LiteLLM. |

**Fusion en un seul fichier : impossible** : chaque service attend sa propre structure ; un YAML unique serait rejeté ou ignoré par l’un des deux.

Dans ce dépôt, **l’URL LiteLLM, la clé « client » et le nom d’alias** pour Hermes sont surtout pilotés par le **`.env`** (variables `HERMES_LITELLM_*` dans `docker-compose.yml`, transmises à Hermes comme `CUSTOM_BASE_URL`, `OPENAI_API_KEY`, `HERMES_INFERENCE_MODEL`, etc.). **`hermes-config.yaml`** ne garde que le minimum côté Hermes (`provider: custom`, repli `default`, `context_length`). Pour changer la **fenêtre de contexte** (non exposée en env documentée), édite ce fichier.

---

# Contenu du dossier

- docker-compose.yml
- Dockerfile.hermes (embarque `hermes-config.yaml` et nettoie un ancien mauvais dossier `/opt/data/config.yaml`)
- Dockerfile.litellm (installe LiteLLM proxy et copie `litellm-config.yaml` dans l’image pour Coolify)
- litellm-config.yaml (sans secrets : clés providers via `os.environ/…`)
- hermes-config.yaml (bloc `model:` Hermes ; complété par le `.env` pour LiteLLM)
- `.env.example` (liste des variables à renseigner)
- README.md

---

# Prérequis

- VPS Ubuntu
- Docker fonctionnel
- Clé API NVIDIA

---

# Créer une clé API NVIDIA

Créer un compte :

https://build.nvidia.com

Puis :
- créer une API Key
- copier la clé

Format :

nvapi-xxxxxxxx

---

# Secrets et variables d’environnement

LiteLLM a besoin d’un fichier `litellm-config.yaml` pour la **structure** (noms d’alias, `model`, `api_base`). Hermes a besoin d’un fichier **`hermes-config.yaml`** au **format Hermes** (bloc `model:`). Ce ne sont pas les mêmes champs : **un seul YAML ne peut pas servir aux deux** (voir section « Deux fichiers YAML »).

En revanche, les **secrets** ne doivent pas être dans le dépôt : pour LiteLLM, les clés providers sont lues via la syntaxe officielle `os.environ/NOM_VARIABLE` dans `litellm-config.yaml` ([documentation LiteLLM](https://docs.litellm.ai/docs/proxy/configs)). Pour Hermes → LiteLLM, **URL, clé « dummy » / token, nom d’alias** passent par le **`.env`** (`HERMES_LITELLM_*`, voir tableau ci‑dessous et `docker-compose.yml`).

Variables utilisées :

| Variable | Usage |
| --- | --- |
| `NVIDIA_API_KEY` | Obligatoire pour l’alias `fast-model` (Hermes par défaut) |
| `ANTHROPIC_API_KEY` | Optionnel : alias `reasoning-model` |
| `DEEPSEEK_API_KEY` | Optionnel : alias `code-model` |
| `GOOGLE_API_KEY` | Optionnel : alias `vision-model` (Gemini) |
| `HERMES_LITELLM_BASE_URL` | Optionnel : URL de base OpenAI-compatible vers LiteLLM (défaut `http://litellm:4000/v1`) — injectée dans Hermes comme `CUSTOM_BASE_URL` |
| `HERMES_LITELLM_API_KEY` | Optionnel : en-tête `Authorization` côté client Hermes→LiteLLM (défaut `dummy` ; aligne avec un éventuel `master_key` LiteLLM) |
| `HERMES_LITELLM_MODEL` | Optionnel : alias LiteLLM (`fast-model`, `nvidia-llama-3.1-8b`, …) **ou** chaîne complète `nvidia_nim/<id>` (wildcard `nvidia_nim/*` côté proxy ; défaut `fast-model`) |
| `HERMES_INFERENCE_PROVIDER` | Optionnel : forcé à `custom` par défaut |
| `HERMES_API_SERVER_KEY` | **Fortement recommandé** en Internet : Bearer pour l’API / UI Hermes (≥ 8 caractères ; ex. `openssl rand -hex 32`) |
| `HERMES_API_SERVER_ENABLED` | Optionnel : `true` / `false` (défaut `true`) |
| `HERMES_API_SERVER_HOST` | Optionnel : adresse d’écoute (défaut `0.0.0.0`) |
| `HERMES_API_SERVER_PORT` | Optionnel : port dans le conteneur (défaut `8642` ; adapte aussi `HERMES_PUBLISH_PORT` si tu changes le mapping) |
| `HERMES_PUBLISH_PORT` | Optionnel : port exposé sur l’hôte (défaut = port conteneur) |
| `HERMES_CORS_ORIGINS` | Optionnel : origines CORS pour l’UI (ex. `https://hermes.tondomaine.net`). Défaut `*` (pratique en dev, à resserrer en prod) |

En local, copie le modèle puis renseigne les valeurs :

```bash
cp .env.example .env
# éditer .env — le fichier .env est ignoré par git (.gitignore)
docker compose up -d
```

Docker Compose transmet ces variables aux services `litellm` et `hermes` (voir `docker-compose.yml`).

## Déploiement Coolify

Dans l’application Coolify : onglet **Environment**, ajoute les mêmes noms de variables (`NVIDIA_API_KEY`, `HERMES_LITELLM_*`, `HERMES_API_SERVER_KEY`, etc.) avec les valeurs secrètes. Aucun secret n’a besoin d’être dans le dépôt que Coolify clone ; `litellm-config.yaml` et `hermes-config.yaml` restent sans secrets providers côté NVIDIA / autres (clés via l’environnement ou valeurs non sensibles type `dummy`).

Si tu n’utilises pas certains alias LiteLLM, tu peux retirer les entrées correspondantes dans `litellm-config.yaml` pour éviter des erreurs au moment des appels.

**Migration depuis l’ancienne image `ghcr.io/shinyduo/hermes-agent` :** le volume Docker `hermes_data` contenait une autre arborescence (`/app/data`). Pour repartir proprement avec l’image officielle (`/opt/data`), supprime le volume puis relance, par exemple :

```bash
docker compose down
docker volume rm hermes-litellm-stack_hermes_data
docker compose up -d
```

(Adapte le nom du volume si ton dossier projet a un autre nom sur l’hôte.)

---

# Lancer la stack

Sur le VPS, dans le dossier du projet (avec les variables définies, via `.env` ou Coolify) :

```bash
docker compose up -d
```

Cela démarre :

- **LiteLLM** sur le port `4000` (API compatible OpenAI, utilisée en interne par Hermes)
- **Hermes** sur le port `8642` (interface web)

Vérifier que les conteneurs tournent :

```bash
docker compose ps
```

Consulter les journaux en cas de problème :

```bash
docker compose logs -f
```

---

# Accéder à Hermes

Par défaut :

http://IP_DU_VPS:8642

Si tu as défini `HERMES_API_SERVER_KEY`, l’interface ou les clients doivent envoyer cette valeur en en-tête `Authorization: Bearer …` (comportement type API OpenAI). Vérifie le comportement exact sur ton build d’Hermes.

---

# Sécurité (exposition Internet)

**Par défaut, ce dépôt ne fournit ni HTTPS ni « compte utilisateur » devant Hermes.** Toute personne qui peut joindre `http://IP:8642` peut, selon la version d’Hermes, utiliser l’agent (outils, fichiers, etc.). Traite donc l’URL publique comme **sensible**.

Ce que tu peux faire, par ordre de robustesse :

1. **Clé d’accès Hermes** — Avec l’image officielle et `API_SERVER_HOST=0.0.0.0`, la doc impose une **`API_SERVER_KEY`** (≥ 8 caractères). Ce dépôt la fournit via **`HERMES_API_SERVER_KEY`** ([variables d’environnement](https://hermes-agent.nousresearch.com/docs/reference/environment-variables), [Docker](https://hermes-agent.nousresearch.com/docs/user-guide/docker)).

2. **Couche devant l’app (recommandé en plus)** — Coolify, Traefik, Caddy ou nginx : **TLS**, éventuellement **SSO / basic auth** (Authelia, Authentik, accès Cloudflare, etc.). C’est souvent ce qu’on entend par « sécuriser l’interface » pour une app sans login intégré.

3. **Réseau** — Ne pas publier LiteLLM sur Internet : dans `docker-compose.yml`, tu peux **commenter** `4000:4000` pour que seul le réseau Docker (Hermes → LiteLLM) y accède.

4. **LiteLLM** — Si le port `4000` reste exposé, configure un `master_key` côté LiteLLM (voir doc proxy) pour éviter qu’un tiers n’utilise ton proxy et donc tes quotas / facturation.

## Avec Coolify : sous-domaine, TLS et authentification

- **TLS (HTTPS)** — En rattachant un **domaine** (sous-domaine) à ton application dans Coolify, le proxy (Traefik / stack Coolify) obtient en général un certificat **Let’s Encrypt** automatiquement. Hermes derrière le proxy peut rester en HTTP interne ; ce n’est pas lui qui gère le certificat.

- **Port interne Hermes** — L’URL publique reste bien `https://hermes.example.com` sans `:8642`. Le port `8642` est seulement le port **interne conteneur** vers lequel Coolify/Traefik route le trafic. `Dockerfile.hermes` déclare donc `EXPOSE 8642` pour que Coolify sache quel backend utiliser dans une stack Docker Compose.

- **Authentification « devant » Hermes** — Le plus courant est de la mettre **au proxy**, pas dans Hermes lui-même :

  1. **[Basic Auth (Traefik)](https://coolify.io/docs/knowledge-base/proxy/traefik/basic-auth)** — Ce dépôt inclut déjà des **labels** sur le service **`hermes`** dans `docker-compose.yml` ([section *Docker Compose And Services*](https://coolify.io/docs/knowledge-base/proxy/traefik/basic-auth#docker-compose-and-services)) : middleware `hermes-basicauth` + raccourci **`coolify.traefik.middlewares=hermes-basicauth`** pour l’injecter dans la chaîne du routeur Coolify. Renseigne **`HERMES_BASIC_AUTH_USERS`** dans l’onglet **Environment** (valeur = sortie de `htpasswd -nbB user pass`, une ligne `user:hash`). Dans un fichier `.env`, **double chaque `$`** du hash (`$` → `$$`) pour éviter que Compose ne les mange. Si tu ne veux pas Basic Auth, **commente le bloc `labels:`** du service `hermes` avant de déployer (sinon une variable vide peut poser problème côté Traefik). Voir aussi la doc Coolify sur les caractères spéciaux dans les labels.

  2. **SSO / OAuth** — Par exemple [protection avec Authentik (forward auth)](https://coolify.io/docs/knowledge-base/proxy/traefik/protect-services-with-authentik) devant Traefik, ou un équivalent (Authelia, **Cloudflare Access**, etc.) si tu préfères gérer l’accès hors Coolify.

- **En complément** — Définir **`HERMES_API_SERVER_KEY`** (Bearer côté Hermes) : barrière côté application en plus du proxy.

En résumé : **Coolify s’occupe du sous-domaine + SSL** ; pour **qui** peut ouvrir l’URL, ajoute **Basic Auth ou SSO au niveau Traefik** (ou l’équivalent documenté pour ta version de Coolify), et garde Hermes/LiteLLM non exposés inutilement sur des ports publics bruts.

---

# Changer de modèle

**Catalogue NVIDIA (même clé `NVIDIA_API_KEY`)** — liste les ids exposés par ton compte :

```bash
curl -sS -H "Authorization: Bearer $NVIDIA_API_KEY" https://integrate.api.nvidia.com/v1/models | jq '.data[].id'
```

- **N’importe quel modèle** : dans LiteLLM ce dépôt expose une route **wildcard** `nvidia_nim/*`. Côté client (Hermes, curl, Open WebUI, etc.), passe `model` sous la forme **`nvidia_nim/<id>`** (ex. `nvidia_nim/meta/llama-3.1-8b-instruct`). Voir [wildcard routing LiteLLM](https://docs.litellm.ai/docs/wildcard_routing) et [provider NVIDIA NIM](https://docs.litellm.ai/docs/providers/nvidia_nim).
- **Alias courts** : `fast-model`, `nvidia-llama-3.1-8b`, `nvidia-deepseek-v4-flash`, etc. sont définis dans `litellm-config.yaml` ; tu peux en ajouter sur le même modèle (`model: nvidia_nim/...`, `api_key: os.environ/NVIDIA_API_KEY`).

Dans **`litellm-config.yaml`** (autres providers) : chaîne `model:` et `model_name` comme d’habitude.

Dans le **`.env`** : **`HERMES_LITELLM_MODEL`** = alias LiteLLM ou chaîne complète `nvidia_nim/...` (défaut `fast-model`).

Pour la **fenêtre de contexte** Hermes (≥ 64k requis pour l’agent), modifie `context_length` dans **`hermes-config.yaml`** (pas de variable d’environnement documentée à ce jour).

Exemples (NVIDIA, préfixe `nvidia_nim/`) :

- `nvidia_nim/meta/llama-3.1-8b-instruct`
- `nvidia_nim/deepseek-ai/deepseek-v4-flash`
- `nvidia_nim/mistralai/mixtral-8x7b-instruct-v0.1`

Exemples (autres providers, clés séparées) :

- anthropic/claude-sonnet-4
- deepseek/deepseek-chat
- google/gemini-2.5-pro

---

# Pourquoi LiteLLM ?

LiteLLM permet :
- de changer facilement de provider
- d'ajouter plusieurs modèles
- de faire du fallback
- d'ajouter Ollama plus tard
- de centraliser les APIs

Hermes ne dépend alors plus directement d'un provider.

---

# Ressources recommandées

Minimum :

- 4 Go RAM
- 2 vCPU
- 20 Go SSD

---

---

# Documentation

Hermes Agent (amont, doc officielle) :
https://github.com/NousResearch/hermes-agent  
https://hermes-agent.nousresearch.com/docs/

LiteLLM :
https://litellm.ai

NVIDIA API :
https://build.nvidia.com
