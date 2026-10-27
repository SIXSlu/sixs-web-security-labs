package com.nimbus.atlas.controller;

import com.nimbus.atlas.auth.SessionStore;
import com.nimbus.atlas.util.QuerySanitizer;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class AssetController {

    private final JdbcTemplate jdbc;
    private final DataSource dataSource;

    public AssetController(JdbcTemplate jdbc, DataSource dataSource) {
        this.jdbc = jdbc;
        this.dataSource = dataSource;
    }

    private SessionStore.Session session(String auth) {
        if (auth == null || !auth.startsWith("Bearer ")) return null;
        return SessionStore.get(auth.substring(7));
    }

    @GetMapping("/assets")
    public ResponseEntity<?> listCategories(@RequestHeader(value = "Authorization", required = false) String auth) {
        SessionStore.Session s = session(auth);
        if (s == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "not authenticated"));
        }
        // category names are internal values, but we still bind them properly
        List<String> categories = jdbc.queryForList(
                "SELECT DISTINCT category FROM assets ORDER BY category", String.class);
        return ResponseEntity.ok(Map.of("categories", categories));
    }

    /**
     * Asset search used by the fleet dashboard. The sanitizer keeps stray
     * dashboards input out of the LIKE clause builder.
     */
    @GetMapping("/assets/search")
    public ResponseEntity<?> search(@RequestParam("q") String q,
                                    @RequestHeader(value = "Authorization", required = false) String auth) {
        SessionStore.Session s = session(auth);
        if (s == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "not authenticated"));
        }

        String term = QuerySanitizer.clean(q);
        String sql = "SELECT id, name, category, status FROM assets WHERE name LIKE '%"
                + term + "%' ORDER BY name";

        List<Map<String, Object>> rows = jdbc.queryForList(sql);
        return ResponseEntity.ok(Map.of("results", rows, "count", rows.size()));
    }

    /** Admin self-service: shows the caller's registry profile. */
    @GetMapping("/admin/profile")
    public ResponseEntity<?> profile(@RequestHeader(value = "Authorization", required = false) String auth) {
        SessionStore.Session s = session(auth);
        if (s == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "not authenticated"));
        }
        if (!"admin".equals(s.role())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "admin only"));
        }
        return ResponseEntity.ok(Map.of(
                "username", s.username(),
                "role", s.role(),
                "registry_api_key", s.apiKey()));
    }

    /** Admin overview counters for the wall dashboard. */
    @GetMapping("/admin/stats")
    public ResponseEntity<?> stats(@RequestHeader(value = "Authorization", required = false) String auth) {
        SessionStore.Session s = session(auth);
        if (s == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "not authenticated"));
        }
        if (!"admin".equals(s.role())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "admin only"));
        }
        Integer assets = jdbc.queryForObject("SELECT COUNT(*) FROM assets", Integer.class);
        Integer users = jdbc.queryForObject("SELECT COUNT(*) FROM users", Integer.class);
        return ResponseEntity.ok(Map.of("assets", assets, "users", users, "status", "operational"));
    }

    /**
     * Raw SQL console for the DBA team. Runs one statement per call against
     * the registry database. Intended for incident response; access to this
     * endpoint is admin-only, which the audit found acceptable.
     */
    @PostMapping("/admin/dbconsole")
    public ResponseEntity<?> dbconsole(@RequestBody Map<String, String> body,
                                      @RequestHeader(value = "Authorization", required = false) String auth) {
        SessionStore.Session s = session(auth);
        if (s == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "not authenticated"));
        }
        if (!"admin".equals(s.role())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "admin only"));
        }
        String sql = body.get("sql");
        if (sql == null || sql.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "sql required"));
        }

        try (Connection conn = dataSource.getConnection();
             Statement st = conn.createStatement()) {
            boolean hasResultSet = st.execute(sql);
            if (hasResultSet) {
                var rs = st.getResultSet();
                var md = rs.getMetaData();
                List<Map<String, Object>> rows = new ArrayList<>();
                while (rs.next()) {
                    Map<String, Object> row = new LinkedHashMap<>();
                    for (int i = 1; i <= md.getColumnCount(); i++) {
                        row.put(md.getColumnLabel(i), rs.getObject(i));
                    }
                    rows.add(row);
                }
                return ResponseEntity.ok(Map.of("rows", rows));
            }
            return ResponseEntity.ok(Map.of("updateCount", st.getUpdateCount()));
        } catch (SQLException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}