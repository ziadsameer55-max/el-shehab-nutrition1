<?php

namespace Database\Factories;

use App\Models\PatientProfile;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

/** Used by automated tests only; never by seeders (no fake data in the real database). */
class UserFactory extends Factory
{
    protected $model = User::class;

    protected static ?string $password = null;

    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => strtolower(fake()->unique()->safeEmail()),
            'phone' => '+2010'.fake()->numerify('########'),
            'password' => static::$password ??= Hash::make('Password123'),
            'role' => 'patient',
            'locale' => 'ar',
            'email_verified_at' => now(),
            'is_active' => true,
        ];
    }

    public function doctor(): static
    {
        return $this->state(fn () => ['role' => 'doctor']);
    }

    public function inactive(): static
    {
        return $this->state(fn () => ['is_active' => false]);
    }

    /** Creates the matching patient_profiles row, optionally linked to a doctor. */
    public function withProfile(?User $doctor = null): static
    {
        return $this->afterCreating(function (User $user) use ($doctor) {
            if ($user->role === 'patient') {
                PatientProfile::create([
                    'user_id' => $user->id,
                    'primary_doctor_id' => $doctor?->id,
                    'privacy_accepted_at' => now(),
                    'consent_version' => '1.0',
                ]);
            }
        });
    }
}
