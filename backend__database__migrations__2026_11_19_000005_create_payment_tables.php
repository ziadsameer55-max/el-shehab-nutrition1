<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(file_get_contents(database_path('sql/005_payments.up.sql')));
    }

    public function down(): void
    {
        DB::unprepared('DROP TABLE IF EXISTS payment_proofs, payments, payment_methods CASCADE');
    }
};
