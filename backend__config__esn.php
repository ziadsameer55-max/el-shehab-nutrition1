<?php

// EL SHEHAB NUTRITION application settings that come from the environment.
// Business policies (hold times, cancellation window ...) live in the `settings` table, not here.
return [
    'frontend_url' => rtrim(env('FRONTEND_URL', 'http://localhost:3000'), '/'),
    'locales' => ['ar', 'en'],
    'default_locale' => 'ar',
];
