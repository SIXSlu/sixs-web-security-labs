package com.helios.fleetledger.controller;

import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.helios.fleetledger.util.QueryGuard;

/**
 * Public vessel directory. The search box is used by the charter desk and
 * the dry-dock planning team, so it must stay reachable without a login.
 */
@RestController
@RequestMapping("/api/vessels")
public class VesselController {

    private final JdbcTemplate jdbc;

    public VesselController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public List<Map<String, Object>> vessels(@RequestParam(defaultValue = "") String q) {
        String safe = QueryGuard.scrub(q);
        String sql = "SELECT id, name, vessel_class, status FROM vessels "
                   + "WHERE name ILIKE '%" + safe + "%' ORDER BY id";
        return jdbc.queryForList(sql);
    }
}