<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(file_get_contents(database_path('sql/002_users_and_profiles.up.sql')));
    }

    public function down(): void
    {
        DB::unprepared('DROP TABLE IF EXISTS patient_profiles, doctor_profiles, users CASCADE');
    }
};
