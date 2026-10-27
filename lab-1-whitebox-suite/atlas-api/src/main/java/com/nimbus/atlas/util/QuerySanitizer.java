package com.nimbus.atlas.util;

/**
 * Input cleanup for the asset search box.
 *
 * The search endpoint is hit from the fleet dashboard with whatever the
 * operator typed, so we strip out characters that have historically caused
 * problems with our query builder (whitespace, comment markers and the
 * semicolon that one of the dashboards used to send).
 */
public class QuerySanitizer {

    public static String clean(String input) {
        String s = input;
        s = s.replaceAll("\\s+", "");
        s = s.replace("--", "");
        s = s.replace("#", "");
        s = s.replace(";", "");
        return s;
    }
}