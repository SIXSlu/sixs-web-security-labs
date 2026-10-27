package com.notharbor.harbordock.util;

/**
 * The two query "guards" came out of two different review rounds, and
 * nobody has reconciled them. They are the reason both endpoints are
 * still concatenation endpoints instead of real parameters.
 */
public final class QueryGuard {

    private QueryGuard() {
    }

    /** June review: search must never contain spaces or line markers... */
    public static String sanitizeSearch(String q) {
        return q.replace(" ", "")
                .replace("--", "");
    }

    /** Sept review: the stats endpoint saw a report about UNION... */
    public static String sanitizeStats(String code) {
        return code.replaceAll("(?i)union", "");
    }
}