<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * Technical defaults only. Values marked PROVISIONAL are open client decisions
 * (see docs/ARCHITECTURE.md section 12) and can be changed in /doctor/settings.
 * Existing values are never overwritten, so re-running the seeder is safe.
 */
class SettingsSeeder extends Seeder
{
    public function run(): void
    {
        $defaults = [
            'clinic_timezone'          => 'Africa/Cairo',
            'default_locale'           => 'ar',
            'currency'                 => 'EGP',
            'proof_max_kb'             => 5120,
            'proof_allowed_mimes'      => ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'],
            'health_file_max_kb'       => 5120,
            'consent_version'          => '1.0',
            // PROVISIONAL, confirm with the client:
            'booking_hold_minutes'     => 60,    // slot held while waiting for a receipt
            'rejected_hold_minutes'    => 720,   // slot kept after a rejected receipt before release
            'buffer_minutes'           => 0,     // gap added after each session
            'min_notice_hours'         => 2,     // earliest bookable time from now
            'max_advance_days'         => 60,    // furthest bookable date
            'cancellation_window_hours' => 24,   // patient self-cancel allowed until N hours before
        ];

        foreach ($defaults as $key => $value) {
            DB::table('settings')->insertOrIgnore([
                'key'        => $key,
                'value'      => json_encode($value),
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }
}
