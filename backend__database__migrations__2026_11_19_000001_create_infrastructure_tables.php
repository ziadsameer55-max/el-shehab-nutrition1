<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

// EL SHEHAB NUTRITION: Developed & Powered by CODING Systems
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(file_get_contents(database_path('sql/001_infrastructure.up.sql')));
    }

    public function down(): void
    {
        DB::unprepared('DROP TABLE IF EXISTS failed_jobs, job_batches, jobs, cache_locks, cache, sessions, password_reset_tokens CASCADE');
    }
};
