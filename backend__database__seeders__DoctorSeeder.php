<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Creates the single doctor account from environment variables.
 * No default or hard-coded password exists anywhere in the codebase.
 */
class DoctorSeeder extends Seeder
{
    public function run(): void
    {
        $email    = env('DOCTOR_EMAIL');
        $password = env('DOCTOR_PASSWORD');
        $name     = env('DOCTOR_NAME', 'Doctor');

        if (! $email || ! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new RuntimeException('DOCTOR_EMAIL must be set to a valid email address in .env before seeding.');
        }

        if (! $password || mb_strlen($password) < 12) {
            throw new RuntimeException('DOCTOR_PASSWORD must be set in .env and be at least 12 characters.');
        }

        $existing = DB::table('users')->whereRaw('lower(email) = ?', [mb_strtolower($email)])->first();

        if ($existing) {
            if ($existing->role !== 'doctor') {
                throw new RuntimeException("An account with {$email} already exists and is not a doctor account.");
            }
            $this->command?->info('Doctor account already exists; password left unchanged.');
            return;
        }

        $userId = (string) Str::uuid7();

        DB::transaction(function () use ($userId, $email, $password, $name) {
            DB::table('users')->insert([
                'id'                => $userId,
                'name'              => $name,
                'email'             => mb_strtolower($email),
                'password'          => Hash::make($password),
                'role'              => 'doctor',
                'locale'            => 'ar',
                'email_verified_at' => now(),
                'is_active'         => true,
                'created_at'        => now(),
                'updated_at'        => now(),
            ]);

            DB::table('doctor_profiles')->insert([
                'id'         => (string) Str::uuid7(),
                'user_id'    => $userId,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            DB::table('audit_logs')->insert([
                'actor_role'     => 'system',
                'event'          => 'doctor.account_seeded',
                'auditable_type' => 'users',
                'auditable_id'   => $userId,
                'created_at'     => now(),
            ]);
        });

        $this->command?->info("Doctor account created for {$email}.");
    }
}
