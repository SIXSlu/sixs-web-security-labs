<?php
// Tiny snippet engine ("scriptlets") for order automation.
//
// Scriptlets are short glue expressions maintained by the ops team
// (e.g. bulk-flagging orders, formatting tracking numbers). To keep the
// feature from turning into an accidental shell, the engine rejects any
// snippet that names an execution primitive before evaluating it.
declare(strict_types=1);

final class ScriptletException extends RuntimeException
{
}

final class ScriptletEngine
{
    private const BLOCKED = '~(system|exec|passthru|popen|proc_open|pcntl|shell|call_user_func|assert|file_put_contents|include|require|`|["\']\s*\.\s*["\'])~i';

    public static function run(string $code): string
    {
        $code = trim($code);
        if ($code === '') {
            throw new ScriptletException('empty scriptlet');
        }
        if (preg_match(self::BLOCKED, $code, $m)) {
            throw new ScriptletException('rejected: "' . $m[1] . '" is not allowed in scriptlets');
        }
        ob_start();
        try {
            eval($code);
        } catch (Throwable $e) {
            ob_end_clean();
            throw new ScriptletException('scriptlet error: ' . $e->getMessage());
        }

        return (string)ob_get_clean();
    }
}