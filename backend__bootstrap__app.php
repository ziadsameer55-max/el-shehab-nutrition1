<?php

use App\Http\Middleware\ApiHeaders;
use App\Http\Middleware\EnsureRole;
use App\Http\Middleware\SetLocale;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        // Sanctum SPA (cookie) authentication: session + CSRF for requests coming from the Next.js origin.
        $middleware->statefulApi();

        // The API sits behind nginx / the Next.js proxy. Restrict to your proxy IPs in production via TRUSTED_PROXIES.
        $middleware->trustProxies(at: env('TRUSTED_PROXIES', '*'));

        $middleware->alias([
            'role' => EnsureRole::class,
        ]);

        $middleware->api(append: [
            SetLocale::class,
            ApiHeaders::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        // Always answer API calls with JSON (never an HTML error page or a redirect to a login page).
        $exceptions->shouldRenderJsonWhen(
            fn ($request, $e) => $request->is('api/*') || $request->expectsJson()
        );
    })
    ->create();
