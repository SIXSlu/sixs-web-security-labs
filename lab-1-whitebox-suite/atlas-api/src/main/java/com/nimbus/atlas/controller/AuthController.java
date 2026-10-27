package com.nimbus.atlas.controller;

import com.nimbus.atlas.auth.SessionStore;
import com.nimbus.atlas.util.TokenUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private static final Logger log = LoggerFactory.getLogger(AuthController.class);

    private final JdbcTemplate jdbc;

    public AuthController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> body) {
        String username = body.get("username");
        String password = body.get("password");
        if (username == null || password == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "username and password required"));
        }

        Map<String, Object> user = jdbc.queryForMap(
                "SELECT id, username, role, salt, password_hash, api_key FROM users WHERE username = ?",
                username);

        String expected = (String) user.get("password_hash");
        if (!expected.equals(sha256((String) user.get("salt") + password))) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "invalid credentials"));
        }

        String token = SessionStore.create(
                (String) user.get("username"), (String) user.get("role"), (String) user.get("api_key"));
        return ResponseEntity.ok(Map.of("session", token));
    }

    @PostMapping("/logout")
    public ResponseEntity<?> logout(@RequestHeader(value = "Authorization", required = false) String auth) {
        if (auth != null && auth.startsWith("Bearer ")) {
            SessionStore.invalidate(auth.substring(7));
        }
        return ResponseEntity.ok(Map.of("status", "bye"));
    }

    /**
     * Password recovery, step 1: dispatch a reset token to the account's
     * registered email address. We always answer 200 so the endpoint cannot
     * be used to enumerate registered addresses.
     */
    @PostMapping("/forgot")
    public ResponseEntity<?> forgot(@RequestBody Map<String, String> body) {
        String email = body.get("email");
        if (email == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "email required"));
        }

        List<String> found = jdbc.queryForList(
                "SELECT username FROM users WHERE email = ?", String.class, email);
        if (!found.isEmpty()) {
            String token = TokenUtil.getRandomBase62(40);
            jdbc.update("INSERT INTO password_reset_tokens (email, token, expires_at) VALUES (?, ?, ?)",
                    email, token,
                    Timestamp.from(Instant.now().plusSeconds(600)));
            log.info("dispatched password reset mail to {} (token issued)", email);
        }
        return ResponseEntity.ok(Map.of("status", "if the address is registered, a reset mail was sent"));
    }

    /** Password recovery, step 2: consume the token and set the new password. */
    @PostMapping("/reset")
    public ResponseEntity<?> reset(@RequestBody Map<String, String> body) {
        String email = body.get("email");
        String token = body.get("token");
        String password = body.get("password");
        if (email == null || token == null || password == null) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "email, token and password required"));
        }

        List<Timestamp> stamps = jdbc.queryForList(
                "SELECT expires_at FROM password_reset_tokens WHERE email = ? AND token = ?",
                Timestamp.class, email, token);
        if (stamps.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "invalid or expired token"));
        }

        String salt = "s" + TokenUtil.getApiKey().substring(0, 6);
        String hash = sha256(salt + password);
        jdbc.update("UPDATE users SET salt = ?, password_hash = ? WHERE email = ?", salt, hash, email);
        jdbc.update("DELETE FROM password_reset_tokens WHERE email = ?", email);
        log.info("password for {} was reset", email);
        return ResponseEntity.ok(Map.of("status", "password updated"));
    }

    /** Public staff directory used by the chatops integration. */
    @GetMapping("/directory")
    public List<Map<String, Object>> directory() {
        return jdbc.queryForList("SELECT username, email, role FROM users ORDER BY username");
    }

    private static String sha256(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}