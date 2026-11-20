<?php

namespace App\Providers;

use App\Models\User;
use App\Support\PatientAccess;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Validation\Rules\Password;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        Password::defaults(fn () => Password::min(10)->letters()->numbers());

        // Authorization entry points used by every controller in later phases.
        Gate::define('access-patient', fn (User $actor, User $patient) => PatientAccess::allows($actor, $patient));
        Gate::define('doctor-only', fn (User $actor) => $actor->is_active && $actor->isDoctor());

        // Coarse per-IP limit on unauthenticated auth endpoints (login also has a per-account limiter).
        RateLimiter::for('auth', fn (Request $request) => Limit::perMinute(10)->by($request->ip()));
    }
}
