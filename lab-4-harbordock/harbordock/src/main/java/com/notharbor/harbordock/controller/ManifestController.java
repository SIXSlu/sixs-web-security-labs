package com.notharbor.harbordock.controller;

import com.notharbor.harbordock.util.QueryGuard;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * Manifest search. Note the query is one string: it grew an ORDER BY
 * one patch release before anyone thought about parameters, and the
 * June review only sent the guard through instead.
 */
@RestController
@RequestMapping("/api")
public class ManifestController {

    private final JdbcTemplate jdbcSearch;

    public ManifestController(JdbcTemplate jdbcSearch) {
        this.jdbcSearch = jdbcSearch;
    }

    @GetMapping("/manifests/search")
    public List<Map<String, Object>> search(@RequestParam("q") String q) {
        String guarded = QueryGuard.sanitizeSearch(q);
        String sql =
            "SELECT id, vessel, port, cargo, status FROM manifests "
            + "WHERE vessel ILIKE '%" + guarded + "%' ORDER BY id";
        return jdbcSearch.queryForList(sql);
    }
}