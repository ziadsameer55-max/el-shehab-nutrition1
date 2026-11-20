<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class LoginTest extends TestCase
{
    use RefreshDatabase;

    public function test_patient_can_log_in(): void
    {
        $user = User::factory()->withProfile()->create(['email' => 'p@example.com']);

        $this->spa()->postJson('/api/auth/login', ['email' => 'P@Example.com', 'password' => 'Password123'])
            ->assertOk()
            ->assertJsonPath('id', $user->id)
            ->assertJsonPath('role', 'patient');

        $this->assertAuthenticatedAs($user, 'web');
        $this->assertNotNull($user->fresh()->last_login_at);
        $this->assertTrue(DB::table('audit_logs')->where('event', 'auth.login')->exists());
    }

    public function test_doctor_login_reports_the_doctor_role(): void
    {
        User::factory()->doctor()->create(['email' => 'd@example.com']);

        $this->spa()->postJson('/api/auth/login', ['email' => 'd@example.com', 'password' => 'Password123'])
            ->assertOk()
            ->assertJsonPath('role', 'doctor')
            ->assertJsonPath('health_profile_completed', null);
    }

    public function test_wrong_password_and_unknown_email_give_the_same_message(): void
    {
        User::factory()->create(['email' => 'p@example.com']);

        $wrongPassword = $this->spa('en')->postJson('/api/auth/login', ['email' => 'p@example.com', 'password' => 'Wrong12345']);
        $unknownEmail = $this->spa('en')->postJson('/api/auth/login', ['email' => 'nobody@example.com', 'password' => 'Wrong12345']);

        $wrongPassword->assertUnprocessable()->assertJsonValidationErrors('email');
        $unknownEmail->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->assertSame($wrongPassword->json('errors.email'), $unknownEmail->json('errors.email'));
        $this->assertGuest('web');
    }

    public function test_disabled_account_cannot_log_in(): void
    {
        User::factory()->inactive()->create(['email' => 'off@example.com']);

        $this->spa()->postJson('/api/auth/login', ['email' => 'off@example.com', 'password' => 'Password123'])
            ->assertUnprocessable();

        $this->assertGuest('web');
    }

    public function test_repeated_failures_are_rate_limited(): void
    {
        User::factory()->create(['email' => 'p@example.com']);

        for ($i = 0; $i < 5; $i++) {
            $this->spa()->postJson('/api/auth/login', ['email' => 'p@example.com', 'password' => 'Wrong12345'])
                ->assertUnprocessable();
        }

        // even the correct password is refused while locked out
        $this->spa()->postJson('/api/auth/login', ['email' => 'p@example.com', 'password' => 'Password123'])
            ->assertStatus(429);

        $this->assertGuest('web');
    }
}
