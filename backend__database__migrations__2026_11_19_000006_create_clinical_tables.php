<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(file_get_contents(database_path('sql/006_clinical.up.sql')));
    }

    public function down(): void
    {
        DB::unprepared('DROP TABLE IF EXISTS patient_files, progress_records, meal_items, diet_meals, diet_plans CASCADE');
    }
};
