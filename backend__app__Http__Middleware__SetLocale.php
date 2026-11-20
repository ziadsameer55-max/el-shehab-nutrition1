<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Chooses the language for validation messages and emails:
 * explicit Accept-Language (sent by the frontend from the current page language),
 * else the signed-in user's saved preference, else Arabic.
 */
class SetLocale
{
    public function handle(Request $request, Closure $next): Response
    {
        $supported = config('esn.locales');
        $locale = null;

        if ($request->headers->has('Accept-Language')) {
            $locale = $request->getPreferredLanguage($supported);
        }

        if (! in_array($locale, $supported, true)) {
            $stored = $request->user()?->locale;
            $locale = in_array($stored, $supported, true) ? $stored : config('esn.default_locale');
        }

        app()->setLocale($locale);

        return $next($request);
    }
}
