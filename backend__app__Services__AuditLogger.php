<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Writes to the append-only audit_logs table (UPDATE/DELETE are blocked by a database trigger).
 * Used for sensitive actions: payment decisions, plan changes, cancellations, role changes, auth events.
 */
final class AuditLogger
{
    private const SECRET_KEYS = ['password', 'password_confirmation', 'token', 'remember_token', 'current_password'];

    public static function record(
        string $event,
        ?Model $subject = null,
        ?array $old = null,
        ?array $new = null,
        ?array $meta = null,
        ?User $actor = null,
    ): void {
        if ($actor === null) {
            $authenticated = Auth::user();
            $actor = $authenticated instanceof User ? $authenticated : null;
        }

        $request = app()->bound('request') ? request() : null;

        DB::table('audit_logs')->insert([
            'actor_id' => $actor?->getKey(),
            'actor_role' => $actor?->role ?? 'system',
            'event' => $event,
            'auditable_type' => $subject?->getTable(),
            'auditable_id' => $subject?->getKey(),
            'old_values' => self::encode($old),
            'new_values' => self::encode($new),
            'metadata' => self::encode($meta),
            'ip_address' => $request?->ip(),
            'user_agent' => $request ? Str::limit((string) $request->userAgent(), 500, '') : null,
            'created_at' => now(),
        ]);
    }

    private static function encode(?array $values): ?string
    {
        if ($values === null) {
            return null;
        }

        return json_encode(
            array_diff_key($values, array_flip(self::SECRET_KEYS)),
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
        );
    }
}
