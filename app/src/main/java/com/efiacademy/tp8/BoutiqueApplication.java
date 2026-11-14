package com.efiacademy.tp8;

import java.util.List;
import java.util.Map;

import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * TP8 — Mini-application « boutique ».
 *
 * Trois endpoints seulement, et PAS UNE SEULE ligne liée à OpenTelemetry :
 * les traces apparaissent parce que l'agent Java est injecté au démarrage
 * (-javaagent), pas parce que le code en parle.
 */
@SpringBootApplication
@RestController
public class BoutiqueApplication {

    private final JdbcTemplate jdbc;

    public BoutiqueApplication(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public static void main(String[] args) {
        SpringApplication.run(BoutiqueApplication.class, args);
    }

    /** Crée et remplit la table au premier démarrage. */
    @Bean
    CommandLineRunner initSchema(JdbcTemplate jdbc) {
        return args -> {
            jdbc.execute("""
                CREATE TABLE IF NOT EXISTS produit (
                    id    SERIAL PRIMARY KEY,
                    nom   TEXT NOT NULL,
                    prix  NUMERIC(8,2) NOT NULL,
                    stock INTEGER NOT NULL DEFAULT 0
                )""");
            Integer n = jdbc.queryForObject("SELECT count(*) FROM produit", Integer.class);
            if (n != null && n == 0) {
                jdbc.update("""
                    INSERT INTO produit (nom, prix, stock) VALUES
                      ('Clavier mécanique', 89.90, 42),
                      ('Écran 27 pouces', 249.00, 12),
                      ('Souris verticale', 54.50, 7),
                      ('Casque antibruit', 179.00, 23),
                      ('Webcam 1080p', 69.90, 31)""");
            }
        };
    }

    /** Sonde de vivacité utilisée par le healthcheck Docker. */
    @GetMapping("/healthz")
    public ResponseEntity<String> healthz() {
        return ResponseEntity.ok("ok");
    }

    /**
     * Liste des produits.
     *
     * @param lent si 1, la requête SQL dort volontairement côté PostgreSQL.
     *             C'est le span lent que tu devras retrouver dans Tempo :
     *             le temps est passé dans la BASE, pas dans l'application.
     */
    @GetMapping("/produits")
    public List<Map<String, Object>> produits(@RequestParam(defaultValue = "0") String lent) {
        if ("1".equals(lent)) {
            // pg_sleep bloque la connexion côté serveur PostgreSQL : l'agent
            // OpenTelemetry le voit comme un span « SELECT » très long.
            jdbc.queryForObject("SELECT pg_sleep(1.2)", String.class);
        }
        return jdbc.queryForList("SELECT id, nom, prix, stock FROM produit ORDER BY id");
    }

    /** Un produit par son identifiant. */
    @GetMapping("/produits/{id}")
    public ResponseEntity<Map<String, Object>> produit(@PathVariable int id) {
        List<Map<String, Object>> rows =
                jdbc.queryForList("SELECT id, nom, prix, stock FROM produit WHERE id = ?", id);
        if (rows.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(rows.get(0));
    }
}
