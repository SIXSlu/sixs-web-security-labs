package com.nimbus.atlas.auth;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory session store. Sessions are lost on restart, which is
 * acceptable for this service: users simply log in again.
 */
public class SessionStore {

    public record Session(String username, String role, String apiKey) {}

    private static final Map<String, Session> SESSIONS = new ConcurrentHashMap<>();

    public static String create(String username, String role, String apiKey) {
        String token = UUID.randomUUID().toString().replace("-", "");
        SESSIONS.put(token, new Session(username, role, apiKey));
        return token;
    }

    public static Session get(String token) {
        if (token == null) return null;
        return SESSIONS.get(token);
    }

    public static void invalidate(String token) {
        if (token != null) SESSIONS.remove(token);
    }
}