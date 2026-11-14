# TP8 — Guide formateur

> Ce fichier n'est pas destiné aux candidats. Le dossier `solution/` non plus.

## 1. Ce que le TP évalue

| Étape | Compétence | Fichier produit par le candidat |
|---|---|---|
| 1–2 | Lire une architecture, écrire une configuration de scrape | `prometheus/prometheus.yml` |
| 3 | Relier un exporter à sa source (mod_status) | — |
| 4 | Écrire des règles PromQL, choisir un `for:` | `prometheus/rules/*.yml` |
| 5 | Routage, regroupement, inhibition, silence | `alertmanager/alertmanager.yml` |
| 6 | Comprendre push vs pull, `honor_labels` | — |
| 7 | Provisioning Grafana, variable de dashboard | export JSON |
| 8–14 | Traces, Collector, agent Java, corrélation | `otel-collector/config.yaml` |

Durée observée : **4 h** pour le socle (étapes 0 à 7 et 15), **2 h** pour la
partie traces (étapes 8 à 14). Prévoir une pause entre les deux.

## 2. Ressources nécessaires

Une VM Linux par candidat, avec Docker Engine et Compose v2.
**Mesures réelles** relevées sur la stack en fonctionnement (`docker stats`,
stack complète, trafic en cours) :

| Service | RAM mesurée | Plafond `mem_limit` | CPU |
|---|---|---|---|
| prometheus | 46 Mo | 512 Mo | 1.0 |
| grafana | 226 Mo | 512 Mo | 1.0 |
| alertmanager | 12 Mo | 128 Mo | 0.5 |
| pushgateway | 9 Mo | 64 Mo | 0.3 |
| node-exporter | 10 Mo | 64 Mo | 0.3 |
| httpd | 6 Mo | 128 Mo | 0.5 |
| apache-exporter | 7 Mo | 64 Mo | 0.3 |
| mailpit | 10 Mo | 128 Mo | 0.3 |
| **Socle** | **≈ 330 Mo** | 1 600 Mo | 4.2 |
| tempo | 103 Mo | 512 Mo | 1.0 |
| app (JVM, `-Xmx256m`) | 221 Mo | 512 Mo | 1.0 |
| postgres | 48 Mo | 256 Mo | 0.5 |
| otel-collector | 42 Mo | 256 Mo | 0.5 |
| **Profil traces** | **≈ 415 Mo** | 1 536 Mo | 3.0 |
| **TOTAL par candidat** | **≈ 745 Mo** | 3 136 Mo | 7.2 |

Les plafonds sont volontairement larges : ils protègent l'hyperviseur sans
brider une stack qui travaille. Prometheus et Grafana grossissent en séance —
**compte 1,2 à 1,5 Go par candidat** pour dimensionner.

**Pour 20 candidats : environ 25 à 30 Go de RAM** et 2 vCPU par VM.
Les pics CPU sont courts (génération de trafic, compaction Tempo).

Disque : rétention Prometheus 2 jours, rétention Tempo 24 h, journaux Docker
plafonnés à 30 Mo par conteneur. Compte 5 Go par candidat, large.

### Variante allégée si l'hyperviseur est juste

1. **Traces en rotation** : la moitié du groupe fait les étapes 8 à 14 pendant
   que l'autre moitié fait le socle, puis on échange. Divise par deux le pic.
2. **Couper le metrics-generator** : dans `tempo/tempo.yaml`, vider
   `overrides.defaults.metrics_generator.processors` → Tempo retombe à ~40 Mo.
   Contrepartie : plus de span-metrics, donc plus d'exemplars ni de service
   graph — l'étape 13 devient une lecture de trace sans corrélation.
3. **Baisser la JVM** : `-Xmx128m` dans `JAVA_TOOL_OPTIONS`. L'application
   tient, le démarrage est un peu plus long.
4. **Grafana partagé** : une seule instance pour la salle, avec une source
   Prometheus par candidat. Économise ~220 Mo par candidat, au prix du
   provisioning à faire à la main.

## 3. Préparation avant la séance

```bash
# Sur chaque VM candidat, en avance : pré-télécharger les images
docker compose pull
docker compose --profile traces pull
docker compose --profile traces build app     # ~2 min, Maven télécharge ses dépendances
```

L'image `tp8/boutique-java:1.0.0` peut aussi être construite **une fois** puis
distribuée (`docker save` / `docker load`, ou un registre interne) : les 20 VM
n'ont alors pas besoin d'atteindre Maven Central.

Vérifie aussi que les ports du `.env` sont libres sur chaque VM.

## 4. Pièges rencontrés — et ce qu'ils enseignent

| Piège | Symptôme | Ce qu'on en fait |
|---|---|---|
| Port déjà pris | `Bind for 0.0.0.0:8080 failed` et le conteneur reste **créé mais sans réseau** ; un `up -d` suivant le « démarre » dans cet état cassé, et il devient injoignable par son nom DNS | Toujours `docker compose rm -sf <service>` avant de relancer après un conflit de port. Excellent exemple de panne qui ne ressemble pas à sa cause. |
| `honor_labels` oublié | Les métriques de sauvegarde apparaissent avec `job="pushgateway"` | Cœur de l'étape 6 |
| Jobs `traces` décommentés sans le profil | `InstanceDown` permanent | Alerte qui crie au loup |
| Nom du label d'exemplar | Tempo écrit `traceID`, le SDK OpenTelemetry écrit `trace_id` ; un nom erroné ne produit aucune erreur, juste un lien absent | Les deux sont déclarés dans `datasources.yml` |
| Config Tempo 2.x | `field ingester not found in type app.Config` | Tempo 3 a supprimé `ingester:` et `compactor:` ; beaucoup d'exemples en ligne ne démarrent plus |
| `endpoint: localhost` dans le Collector | Rien n'arrive, aucune erreur | Il faut `0.0.0.0` : sinon on n'écoute que dans le conteneur |
| Log `error ... no jobs found` de Tempo | Inquiète les candidats | Normal : le worker de compaction interroge l'ordonnanceur qui n'a rien à faire |
| `/server-status` ouvert | — | Volontaire en salle ; rappeler le `Require local` du TP2 pour la production |

## 5. Corrigé rapide

Tout est dans `solution/`, fichier par fichier, avec les commentaires
d'explication :

```
solution/prometheus/prometheus.yml          TODO 1 à 8
solution/prometheus/rules/recording.yml     TODO 9
solution/prometheus/rules/alerts.yml        TODO 10 à 13
solution/alertmanager/alertmanager.yml      TODO 14 à 18
solution/otel-collector/config.yaml         TODO 19 à 24
```

Pour dépanner un candidat bloqué, ou pour démontrer la chaîne complète :

```bash
cp solution/prometheus/prometheus.yml      prometheus/prometheus.yml
cp solution/prometheus/rules/*.yml         prometheus/rules/
cp solution/alertmanager/alertmanager.yml  alertmanager/alertmanager.yml
cp solution/otel-collector/config.yaml     otel-collector/config.yaml
curl -X POST http://localhost:9090/-/reload
docker compose restart alertmanager otel-collector
```

Attention : `solution/prometheus/prometheus.yml` garde les jobs `otel-collector`
et `tempo` **commentés**. Décommente-les si le profil `traces` tourne.

## 6. Scénarios de démonstration

```bash
# Alerte critique de bout en bout (≈ 90 s avant l'e-mail)
docker compose stop httpd
#   -> ApacheDown PENDING puis FIRING, route severity=critical,
#      e-mail « [TP8][CRITIQUE] ApacheDown » dans Mailpit,
#      et ApacheNoTraffic passe en « suppressed » par l'inhibit_rule.
docker compose start httpd

# Inhibition, sans attendre : on injecte l'alerte conséquence à la main
curl -XPOST http://localhost:9093/api/v2/alerts -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"ApacheNoTraffic","severity":"warning","service":"web","instance":"apache-exporter:9117"}}]'
curl -s 'http://localhost:9093/api/v2/alerts?inhibited=true' | grep -o '"state":"[a-z]*"'

# Sauvegarde trop ancienne, sans attendre 24 h : baisser le seuil de
# BackupTooOld à 120 au lieu de 86400, recharger, attendre le « for: 10m ».

# Trace lente garantie
curl -s 'http://localhost:8081/produits?lent=1' >/dev/null
```

## 7. Ce qui a été réellement testé

Stack lancée et vérifiée de bout en bout sur Docker 29.8.1 :

- squelettes : la stack démarre, `promtool check config` et `amtool
  check-config` passent ;
- solution : 4 cibles UP (prometheus, node, apache, pushgateway),
  `promtool check rules` = 3 règles d'enregistrement + 7 règles d'alerte ;
- `instance:node_cpu_utilisation:ratio`, `rate(apache_accesses_total[1m])`,
  `apache_workers{state=...}` renvoient des valeurs ;
- `scripts/backup-job.sh` : métrique visible dans la Pushgateway **et** dans
  Prometheus avec ses labels d'origine ;
- `docker compose stop httpd` → `ApacheDown` FIRING → **2 e-mails reçus dans
  Mailpit** sur le receiver `astreinte` ;
- `inhibit_rule` : `ApacheNoTraffic` passe bien en `suppressed` ;
- `amtool silence add` : silence créée et listée ;
- Grafana : 2 sources provisionnées, 3 dashboards chargés, requêtes OK ;
- profil traces : Tempo `ready`, trace complète
  `GET /produits` 1206 ms → `SELECT pg_sleep(?)` 1203 ms → `SELECT ... produit`
  0,4 ms, `traces_spanmetrics_*` et `traces_service_graph_request_total`
  présentes dans Prometheus, exemplars portant un `traceID` exploitable,
  service graph `user → boutique-java → postgres`.
