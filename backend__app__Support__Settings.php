<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;

/**
 * Reads business settings from the `settings` table (editable by the doctor).
 * Nothing business-related is hard-coded in the application.
 */
final class Settings
{
    public static function get(string $key, mixed $default = null): mixed
    {
        $raw = DB::table('settings')->where('key', $key)->value('value');

        return $raw === null ? $default : json_decode($raw, true);
    }
}
