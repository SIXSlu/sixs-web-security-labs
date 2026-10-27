package com.helios.fleetledger.controller;

import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.helios.fleetledger.util.QueryGuard;

/**
 * Fleet statistics counters. Only the aggregated count is returned — the
 * finance team did not want per-owner vessel lists exposed on this endpoint.
 */
@RestController
@RequestMapping("/api/fleet")
public class StatsController {

    private final JdbcTemplate jdbc;

    public StatsController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/stats")
    public Map<String, Object> stats(@RequestParam(defaultValue = "") String owner) {
        String safe = QueryGuard.scrub(owner);
        String sql = "SELECT COUNT(*) FROM vessels WHERE owner_unit = '" + safe + "'";
        Long count = jdbc.queryForObject(sql, Long.class);
        return Map.of("owner_count", count == null ? 0L : count);
    }
}