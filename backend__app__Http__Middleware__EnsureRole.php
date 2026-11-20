<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Usage: ->middleware(['auth:sanctum', 'role:doctor']). Enforced on the server for every request;
 * hiding buttons in the UI is never relied on.
 */
class EnsureRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user) {
            return response()->json(['message' => __('auth.unauthenticated')], 401);
        }

        if (! $user->is_active || ! in_array($user->role, $roles, true)) {
            return response()->json(['message' => __('auth.forbidden')], 403);
        }

        return $next($request);
    }
}
