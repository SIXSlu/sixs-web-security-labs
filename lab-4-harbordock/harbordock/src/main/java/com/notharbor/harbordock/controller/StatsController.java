package com.notharbor.harbordock.controller;

import com.notharbor.harbordock.util.QueryGuard;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Berth statistics. Returns a single scalar (the console widgets need
 * a number, not rows), so anything beyond a count has to come out the
 * hard way. The Sept review stripped its own keyword by hand, and this
 * endpoint uses its own connection because the vault table is not
 * granted to the search login.
 */
@RestController
@RequestMapping("/api")
public class StatsController {

    private final JdbcTemplate jdbcStats;

    public StatsController(JdbcTemplate jdbcStats) {
        this.jdbcStats = jdbcStats;
    }

    @GetMapping("/ports/stats")
    public Map<String, Object> stats(@RequestParam("code") String code) {
        String guarded = QueryGuard.sanitizeStats(code);
        String sql =
            "SELECT count(*) AS berthed FROM manifests WHERE port = '"
            + guarded + "'";
        Long n = jdbcStats.queryForObject(sql, Long.class);
        return Map.of("count", n == null ? 0 : n);
    }
}