<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

/**
 * Production-safe seeding: only system settings and the doctor account.
 * No fake services, prices, patients or content is ever created here.
 * The doctor enters real catalog data from the dashboard.
 */
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            SettingsSeeder::class,
            DoctorSeeder::class,
        ]);
    }
}
