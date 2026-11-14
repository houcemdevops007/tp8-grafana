# ---------------------------------------------------------------------------
# TP8 — Image de la mini-application « boutique ».
#
# Construction en deux étapes :
#   1. maven compile le .jar
#   2. l'image finale ne garde que le JRE, le .jar et l'agent OpenTelemetry
#
#   docker compose --profile traces build app
# ---------------------------------------------------------------------------

# --- Étape 1 : compilation --------------------------------------------------
FROM maven:3.9-eclipse-temurin-21-alpine AS build
WORKDIR /src

# Les dépendances d'abord : cette couche est réutilisée tant que pom.xml ne
# change pas, ce qui évite de retélécharger Maven Central à chaque build.
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q clean package -DskipTests

# --- Étape 2 : agent OpenTelemetry -----------------------------------------
# Version FIGÉE : un agent qui change tout seul changerait le nom des spans
# d'une séance à l'autre.
FROM alpine:3.22 AS agent
ARG OTEL_AGENT_VERSION=2.33.1
RUN apk add --no-cache curl && \
    curl -fsSL -o /opentelemetry-javaagent.jar \
      "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_AGENT_VERSION}/opentelemetry-javaagent.jar"

# --- Étape 3 : image finale -------------------------------------------------
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# L'application ne tourne pas en root.
RUN addgroup -S boutique && adduser -S boutique -G boutique

COPY --from=build /src/target/boutique.jar /app/boutique.jar
COPY --from=agent /opentelemetry-javaagent.jar /opt/opentelemetry-javaagent.jar

USER boutique
EXPOSE 8080

# L'agent n'est PAS activé ici : il l'est par la variable JAVA_TOOL_OPTIONS
# du docker-compose.yml. Tu peux donc démarrer l'application avec ou sans
# instrumentation, sans reconstruire l'image.
ENTRYPOINT ["java", "-jar", "/app/boutique.jar"]
