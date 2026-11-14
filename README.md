# TP8 — Prometheus autonome : pull, Alertmanager et Pushgateway

Ressources du TP8 du **Parcours Observabilité** (EFI Academy).

Dans les TP1 à TP7, Grafana Alloy **poussait** tes métriques vers Mimir et tes
logs vers Loki, à travers le proxy `lb-0`. Ici, tu montes ta propre stack
Prometheus : c'est Prometheus qui **va chercher** les métriques, lui-même, chez
chaque exporter. Tu écris `prometheus.yml`, les règles, `alertmanager.yml`, et
tu branches la chaîne complète jusqu'à l'e-mail d'alerte.

La seconde moitié du TP ajoute le troisième signal — les **traces** — avec
OpenTelemetry et Tempo.

## Prérequis

- Une VM Linux à toi, avec Docker Engine et le plugin Compose v2
  (`docker compose version` doit répondre).
- 4 Go de RAM libres et 10 Go de disque.
- Les TP1 à TP7 terminés : tu vas comparer en permanence avec ce que tu y as vu.

## Démarrage

```bash
git clone https://github.com/houcemdevops007/tp8-grafana.git
cd tp8-grafana
cp .env.example .env
# Mets ton identifiant de candidat dans .env (CAND=cand-07 par exemple)
docker compose up -d
docker compose ps
```

| Service | URL par défaut |
|---|---|
| Prometheus | http://VM:9090 |
| Alertmanager | http://VM:9093 |
| Pushgateway | http://VM:9091 |
| Grafana | http://VM:3000 (`admin` / mot de passe du `.env`) |
| Mailpit (faux SMTP) | http://VM:8025 |
| Apache de démonstration | http://VM:8080 |

Partie traces (étapes 8 à 14) :

```bash
docker compose --profile traces build app     # une seule fois
docker compose --profile traces up -d
```

| Service | URL par défaut |
|---|---|
| Tempo | http://VM:3200 |
| Application Java | http://VM:8081 |

## Ce que tu écris toi-même

Ces fichiers sont des **squelettes** : ils démarrent tels quels, et contiennent
des `# TODO n :` numérotés qui suivent l'ordre des étapes du tutoriel.

```
prometheus/prometheus.yml        TODO 1 à 8
prometheus/rules/recording.yml   TODO 9
prometheus/rules/alerts.yml      TODO 10 à 13
alertmanager/alertmanager.yml    TODO 14 à 18
otel-collector/config.yaml       TODO 19 à 24
```

`tempo/tempo.yaml` est fourni complet : tu ne le configures pas, tu l'expliques.

## Arborescence

```
.
├── docker-compose.yml           la stack complète (profil « traces » inclus)
├── .env.example                 ports, identifiants, CAND
├── prometheus/                  squelettes à compléter
├── alertmanager/                squelette à compléter
├── otel-collector/              squelette à compléter
├── tempo/tempo.yaml             fourni complet et commenté
├── apache/                      fragment de configuration + pages de test
├── grafana/provisioning/        sources de données et dashboards
├── app/                         mini-application Java + Dockerfile
├── scripts/                     trafic Apache, trafic application, job de sauvegarde
├── solution/                    corrigé — réservé au formateur
└── README-formateur.md          préparation de la séance
```

## Nettoyage

```bash
docker compose --profile traces down -v
```
