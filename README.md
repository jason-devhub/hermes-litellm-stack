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

Ce dépôt utilise l’image **`nousresearch/hermes-agent`** avec la commande **`gateway run`**, le **dashboard** sur `:9119` (`HERMES_DASHBOARD=1`) et les données sous **`/opt/data`** ([guide Docker](https://hermes-agent.nousresearch.com/docs/user-guide/docker)). L’interface web est **[Hermes Workspace](https://github.com/outsourc-e/hermes-workspace)** (`ghcr.io/outsourc-e/hermes-workspace`), pas Open WebUI. Sur Coolify, Hermes est construit via `Dockerfile.hermes` pour embarquer `hermes-config.yaml` dans l’image au lieu de le monter comme fichier sous `/opt/data/config.yaml`.

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
| `HERMES_UID` / `HERMES_GID` | Optionnel : propriétaire du volume partagé (défaut **10010**, aligné sur Hermes Workspace) |
| `HERMES_PASSWORD` | **Obligatoire** : mot de passe de session Hermes Workspace (l’UI refuse de démarrer sur `0.0.0.0` sans secret) |
| `HERMES_WORKSPACE_COOKIE_SECURE` | `0` si tu ouvres l’UI en **http://** (IP, LAN) ; `1` + `TRUST_PROXY=1` derrière **Coolify/HTTPS** |
| `HERMES_WORKSPACE_TRUST_PROXY` | `1` uniquement derrière un reverse proxy de confiance (Coolify, Traefik) |

En local, copie le modèle puis renseigne les valeurs :

```bash
cp .env.example .env
# éditer .env — le fichier .env est ignoré par git (.gitignore)
docker compose up -d
```

Docker Compose transmet ces variables aux services `litellm` et `hermes` (voir `docker-compose.yml`).

## Déploiement Coolify

Dans l’application Coolify : onglet **Environment**, ajoute les mêmes noms de variables (`NVIDIA_API_KEY`, `HERMES_LITELLM_*`, `HERMES_API_SERVER_KEY`, `HERMES_PASSWORD`, etc.) avec les valeurs secrètes. Aucun secret n’a besoin d’être dans le dépôt que Coolify clone ; `litellm-config.yaml` et `hermes-config.yaml` restent sans secrets providers côté NVIDIA / autres (clés via l’environnement ou valeurs non sensibles type `dummy`).

Si tu n’utilises pas certains alias LiteLLM, tu peux retirer les entrées correspondantes dans `litellm-config.yaml` pour éviter des erreurs au moment des appels.

**Migration depuis l’ancienne image `ghcr.io/shinyduo/hermes-agent` :** le volume Docker `hermes_data` contenait une autre arborescence (`/app/data`). Pour repartir proprement avec l’image officielle (`/opt/data`), supprime le volume puis relance, par exemple :

```bash
docker compose down
docker volume rm hermes-litellm-stack_hermes_data
docker compose up -d
```

(Adapte le nom du volume si ton dossier projet a un autre nom sur l’hôte.)

**Migration depuis Open WebUI :** le service `open-webui` et le volume `open_webui_data` ont été retirés. Tu peux supprimer l’ancien volume si tu n’en as plus besoin :

```bash
docker compose down
docker volume rm hermes-litellm-stack_open_webui_data 2>/dev/null || true
docker compose up -d
```

---

# Lancer la stack

Sur le VPS, dans le dossier du projet (avec les variables définies, via `.env` ou Coolify) :

```bash
docker compose up -d
```

Cela démarre :

- **LiteLLM** sur le port `4000` (API compatible OpenAI, utilisée en interne par Hermes)
- **Hermes** sur les ports internes `8642` (gateway) et `9119` (dashboard)
- **Hermes Workspace** sur le port interne `3000` (interface web native pour l’agent)

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

Par défaut, Hermes expose surtout une API OpenAI-compatible :

http://IP_DU_VPS:8642

Si tu as défini `HERMES_API_SERVER_KEY`, les clients doivent envoyer cette valeur en en-tête `Authorization: Bearer …` (comportement type API OpenAI). Le endpoint principal pour les frontends est `/v1`.

## Accéder à Hermes Workspace

[Hermes Workspace](https://github.com/outsourc-e/hermes-workspace) remplace Open WebUI : c’est l’interface native (chat, mémoire, skills, terminal) branchée sur le gateway Hermes et son dashboard.

Dans Coolify, rattache un domaine au service **`hermes-workspace`** avec le port interne **`3000`** (ex. `https://chat.example.com`).

Au premier accès, connecte-toi avec le mot de passe défini dans **`HERMES_PASSWORD`**. Le workspace parle à Hermes via le réseau Docker :

- `HERMES_API_URL=http://hermes:8642` (gateway)
- `HERMES_DASHBOARD_URL=http://hermes:9119` (sessions, skills, jobs)
- `HERMES_API_TOKEN` = même valeur que **`HERMES_API_SERVER_KEY`** si le gateway est authentifié

Les données agent (config, sessions, mémoire) partagent le volume `hermes_data` ; les fichiers créés depuis le navigateur de fichiers du workspace vont dans `hermes_workspace_files`.

Vérification rapide :

```bash
docker compose exec hermes python3 -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8642/health').read())"
docker compose exec hermes python3 -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:9119/api/status').read())"
```

**Login impossible / warning `plain-HTTP LAN` / erreur 500 au chargement :** en accès **http://** direct, définis `HERMES_WORKSPACE_COOKIE_SECURE=0` (sinon le navigateur rejette les cookies `Secure` en production). Derrière **Coolify en HTTPS**, utilise plutôt `HERMES_WORKSPACE_COOKIE_SECURE=1` et `HERMES_WORKSPACE_TRUST_PROXY=1`. Le message `CLAUDE_DASHBOARD_TOKEN` est un avertissement de dépréciation : le workspace récupère encore le token du dashboard via HTML ; tu peux l’ignorer tant que `enhanced=[sessions, skills, …]` apparaît dans les logs.

**Erreur `EACCES` sur `/home/workspace/.hermes/config.yaml` :** l’agent et le workspace partagent le volume `hermes_data`. L’UI tourne en UID **10010** ; sans `HERMES_UID=10010`, l’agent écrit en **10000** et le workspace ne peut pas modifier la config. Ce dépôt fixe `HERMES_UID` / `HERMES_GID` à `10010` sur le service `hermes`. Après mise à jour, redémarre pour que l’entrypoint refasse le `chown` du volume :

```bash
docker compose up -d --force-recreate hermes
docker compose restart hermes-workspace
```

Si l’erreur persiste : `docker compose exec -u root hermes chown -R 10010:10010 /opt/data`

---

# Sécurité (exposition Internet)

**Par défaut, ce dépôt ne fournit ni HTTPS ni « compte utilisateur » devant Hermes.** Toute personne qui peut joindre `http://IP:8642` peut, selon la version d’Hermes, utiliser l’agent (outils, fichiers, etc.). Traite donc l’URL publique comme **sensible**.

Ce que tu peux faire, par ordre de robustesse :

1. **Clé d’accès Hermes** — Avec l’image officielle et `API_SERVER_HOST=0.0.0.0`, la doc impose une **`API_SERVER_KEY`** (≥ 8 caractères). Ce dépôt la fournit via **`HERMES_API_SERVER_KEY`** ([variables d’environnement](https://hermes-agent.nousresearch.com/docs/reference/environment-variables), [Docker](https://hermes-agent.nousresearch.com/docs/user-guide/docker)).

2. **Couche devant l’app (recommandé en plus)** — Coolify, Traefik, Caddy ou nginx : **TLS**, éventuellement **SSO / basic auth** (Authelia, Authentik, accès Cloudflare, etc.). C’est souvent ce qu’on entend par « sécuriser l’interface » pour une app sans login intégré.

3. **Réseau** — LiteLLM et Hermes ne publient pas de ports hôte dans ce compose ; Hermes Workspace parle à Hermes via le réseau Docker interne, et Hermes parle à LiteLLM de la même façon.

4. **LiteLLM** — Si le port `4000` reste exposé, configure un `master_key` côté LiteLLM (voir doc proxy) pour éviter qu’un tiers n’utilise ton proxy et donc tes quotas / facturation.

## Avec Coolify : sous-domaine, TLS et authentification

- **TLS (HTTPS)** — En rattachant un **domaine** (sous-domaine) à ton application dans Coolify, le proxy (Traefik / stack Coolify) obtient en général un certificat **Let’s Encrypt** automatiquement. Hermes derrière le proxy peut rester en HTTP interne ; ce n’est pas lui qui gère le certificat.

- **Port interne** — L’URL publique reste `https://chat.example.com` sans `:3000`. Le port `3000` est le port **interne conteneur** du service `hermes-workspace` vers lequel Coolify/Traefik route le trafic.

- **Authentification Workspace** — Définis **`HERMES_PASSWORD`** (session UI). En complément, **`HERMES_API_SERVER_KEY`** protège le gateway Hermes (Bearer).

- **Cookies** — Coolify HTTPS : `HERMES_WORKSPACE_COOKIE_SECURE=1` et `HERMES_WORKSPACE_TRUST_PROXY=1`. Accès direct en `http://` : `HERMES_WORKSPACE_COOKIE_SECURE=0`.

- **SSO / OAuth optionnel** — Tu peux ajouter une couche devant le workspace (Authentik, Authelia, Cloudflare Access) en plus du mot de passe Workspace.

En résumé : **Coolify s’occupe du sous-domaine + SSL** ; expose le service **`hermes-workspace`** uniquement, et garde Hermes/LiteLLM non exposés sur des ports publics bruts.

---

# Changer de modèle

**Catalogue NVIDIA (même clé `NVIDIA_API_KEY`)** — liste les ids exposés par ton compte :

```bash
curl -sS -H "Authorization: Bearer $NVIDIA_API_KEY" https://integrate.api.nvidia.com/v1/models | jq '.data[].id'
```

- **N’importe quel modèle** : dans LiteLLM ce dépôt expose une route **wildcard** `nvidia_nim/*`. Côté client (Hermes, curl, Hermes Workspace, etc.), passe `model` sous la forme **`nvidia_nim/<id>`** (ex. `nvidia_nim/meta/llama-3.1-8b-instruct`). Voir [wildcard routing LiteLLM](https://docs.litellm.ai/docs/wildcard_routing) et [provider NVIDIA NIM](https://docs.litellm.ai/docs/providers/nvidia_nim).
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

Hermes Workspace (interface web) :
https://github.com/outsourc-e/hermes-workspace  
https://hermes-workspace.com/

LiteLLM :
https://litellm.ai

NVIDIA API :
https://build.nvidia.com
