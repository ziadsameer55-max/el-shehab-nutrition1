<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use App\Notifications\ResetPasswordNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    public function test_reset_link_is_sent_to_a_registered_email(): void
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'p@example.com']);

        $this->spa()->postJson('/api/auth/forgot-password', ['email' => 'P@example.com'])->assertOk();

        Notification::assertSentTo($user, ResetPasswordNotification::class);
    }

    public function test_unknown_email_gets_the_same_answer_and_no_mail(): void
    {
        Notification::fake();
        $known = User::factory()->create(['email' => 'p@example.com']);

        $a = $this->spa('en')->postJson('/api/auth/forgot-password', ['email' => 'p@example.com']);
        $b = $this->spa('en')->postJson('/api/auth/forgot-password', ['email' => 'nobody@example.com']);

        $this->assertSame($a->status(), $b->status());
        $this->assertSame($a->json('message'), $b->json('message'));
        Notification::assertSentToTimes($known, ResetPasswordNotification::class, 1);
        Notification::assertCount(1);
    }

    public function test_reset_email_links_to_the_frontend_in_the_users_language(): void
    {
        $arabic = User::factory()->create(['locale' => 'ar']);
        $english = User::factory()->create(['locale' => 'en']);

        $arabicUrl = (new ResetPasswordNotification('tok'))->toMail($arabic)->actionUrl;
        $englishUrl = (new ResetPasswordNotification('tok'))->toMail($english)->actionUrl;

        $this->assertStringStartsWith('http://localhost:3000/reset-password?token=tok', $arabicUrl);
        $this->assertStringStartsWith('http://localhost:3000/en/reset-password?token=tok', $englishUrl);
    }

    public function test_password_can_be_reset_with_a_valid_token(): void
    {
        $user = User::factory()->create(['email' => 'p@example.com']);
        $token = Password::broker()->createToken($user);

        // a pre-existing session for this user must be revoked by the reset
        DB::table('sessions')->insert([
            'id' => 'old-session', 'user_id' => $user->id, 'payload' => 'x', 'last_activity' => time(),
        ]);

        $this->spa()->postJson('/api/auth/reset-password', [
            'token' => $token,
            'email' => 'p@example.com',
            'password' => 'BrandNew12345',
            'password_confirmation' => 'BrandNew12345',
        ])->assertOk();

        $this->assertDatabaseMissing('sessions', ['id' => 'old-session']);
        $this->assertTrue(DB::table('audit_logs')->where('event', 'auth.password_reset')->exists());

        $this->spa()->postJson('/api/auth/login', ['email' => 'p@example.com', 'password' => 'BrandNew12345'])->assertOk();
    }

    public function test_invalid_token_is_rejected(): void
    {
        User::factory()->create(['email' => 'p@example.com']);

        $this->spa()->postJson('/api/auth/reset-password', [
            'token' => 'not-a-real-token',
            'email' => 'p@example.com',
            'password' => 'BrandNew12345',
            'password_confirmation' => 'BrandNew12345',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');
    }

    public function test_token_cannot_be_reused(): void
    {
        $user = User::factory()->create(['email' => 'p@example.com']);
        $token = Password::broker()->createToken($user);
        $body = [
            'token' => $token, 'email' => 'p@example.com',
            'password' => 'BrandNew12345', 'password_confirmation' => 'BrandNew12345',
        ];

        $this->spa()->postJson('/api/auth/reset-password', $body)->assertOk();
        $this->spa()->postJson('/api/auth/reset-password', $body)->assertUnprocessable();
    }
}
