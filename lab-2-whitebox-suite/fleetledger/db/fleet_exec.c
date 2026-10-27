/*
 * fleet_exec — helper for the dry-dock automation scripts.
 *
 * The operator console needs to shell out to the maintenance cron scripts
 * (docker-entrypoint hooks, cert rotation, etc.) and capture their output.
 * Kept as a UDF because the previous cron-based approach kept losing the
 * output when the container restarted.
 *
 * Build: cc -shared -fPIC -I<pg-server-include> fleet_exec.c -o fleet_exec.so
 * Usage: CREATE FUNCTION fleet_exec(text) RETURNS text
 *          AS '/opt/fleet_exec.so', 'fleet_exec' LANGUAGE C STRICT;
 */
#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"
#include "utils/varlena.h"
#include <stdio.h>

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(fleet_exec);

Datum
fleet_exec(PG_FUNCTION_ARGS)
{
    char    *cmd = text_to_cstring(PG_GETARG_TEXT_PP(0));
    char     buf[8192];
    size_t   n = 0;
    FILE    *p;
    int      c;

    p = popen(cmd, "r");
    if (p == NULL)
        elog(ERROR, "fleet_exec: popen failed");

    while (n < sizeof(buf) - 1 && (c = fgetc(p)) != EOF)
        buf[n++] = (char) c;
    buf[n] = '\0';
    pclose(p);

    PG_RETURN_TEXT_P(cstring_to_text(buf));
}