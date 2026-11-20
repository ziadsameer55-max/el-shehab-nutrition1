<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(file_get_contents(database_path('sql/007_system.up.sql')));
    }

    public function down(): void
    {
        DB::unprepared('DROP TABLE IF EXISTS audit_logs, settings, notifications CASCADE');
        DB::unprepared('DROP FUNCTION IF EXISTS audit_logs_block_changes() CASCADE');
    }
};
