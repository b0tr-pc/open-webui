# Hermes-patchad Open WebUI deploy

Det här är den lokala, repo-spårade deployvägen för Open WebUI-instansen som pratar med Hermes.

## Vad den här deployen gör

- bygger en lokal overlay-image från det patchade Open WebUI-repot, inklusive session cleanup i `routers/chats.py` och titel synk i `utils/middleware.py`
- behåller named volume `open-webui` för databasen
- kör containern som `open-webui`
- binder tjänsten på `10.13.37.106:3000`
- skickar vidare Hermes-relaterade env-vars utan att lägga hemligheter i git

## Filer

- `.env.example` mall med ofarliga placeholders
- `.env.runtime` riktig lokal env-fil, ska **inte** committas
- `redeploy.sh` bygger image och startar om containern

## Första gången

```bash
cd /home/admin_ubunt/open-webui-inspect/deploy/hermes-open-webui
cp .env.example .env.runtime
chmod 600 .env.runtime
nano .env.runtime
```

Fyll i riktiga värden från den körande containern eller din riktiga driftkonfig.

## Redeploy

```bash
cd /home/admin_ubunt/open-webui-inspect/deploy/hermes-open-webui
bash redeploy.sh
```

## Verifiering

Efter körning ska skriptet själv:

- bygga imagen
- ersätta containern
- vänta på `healthy`
- köra `GET /health`

## Viktigt

- `.env.runtime` innehåller hemligheter och ska stanna på hosten
- källkoden och deployskriptet ligger i git, så patchen ryker inte vid vanlig container-recreate
- vid framtida upstream-uppdateringar, bygg om från det här repot igen istället för att starta rå upstream-image direkt
