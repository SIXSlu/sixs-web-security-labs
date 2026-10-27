package com.helios.fleetledger.controller;

import java.util.List;
import java.util.Map;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.helios.fleetledger.util.QueryGuard;

/**
 * Dry-dock operator console. Access is granted per API key; keys are handed
 * out by the fleet office and stored in the users table.
 *
 * The ad-hoc query box is operator-only and has been behind the key check
 * since it was added, so the reporting team insisted we keep it (their
 * dashboards break without it). QueryGuard still scrubs the statement —
 * that was the compromise everyone signed.
 */
@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private final JdbcTemplate jdbc;

    public AdminController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private boolean isOperator(String apiKey) {
        if (apiKey == null || apiKey.isBlank()) {
            return false;
        }
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT role FROM users WHERE api_key = ?", apiKey);
        return !rows.isEmpty() && "admin".equals(rows.get(0).get("role"));
    }

    @GetMapping("/console")
    public ResponseEntity<?> console(
            @RequestHeader(value = "X-API-Key", required = false) String apiKey) {
        if (!isOperator(apiKey)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "valid operator key required"));
        }
        List<Map<String, Object>> settings =
                jdbc.queryForList("SELECT key, value FROM settings ORDER BY key");
        return ResponseEntity.ok(settings);
    }

    @PostMapping("/query")
    public ResponseEntity<?> query(
            @RequestHeader(value = "X-API-Key", required = false) String apiKey,
            @RequestBody Map<String, String> body) {
        if (!isOperator(apiKey)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "valid operator key required"));
        }
        String sql = QueryGuard.scrub(body.getOrDefault("sql", ""));
        if (sql.isBlank()) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "sql is required"));
        }
        // the reporting team sends a mix of SELECTs and maintenance
        // statements; the latter return no result set, so fall back to a
        // plain execute and report the command tag instead
        List<Map<String, Object>> rows;
        try {
            rows = jdbc.queryForList(sql);
        } catch (DataAccessException e) {
            jdbc.execute(sql);
            rows = List.of(Map.of("status", "executed"));
        }
        return ResponseEntity.ok(rows);
    }
}