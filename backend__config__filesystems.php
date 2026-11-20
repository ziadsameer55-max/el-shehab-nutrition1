<?php

// "private" holds payment receipts and health files. It has NO url and is never served by the web
// server; files are streamed only by controllers after an authorization check.
return [
    'default' => env('FILESYSTEM_DISK', 'private'),

    'disks' => [
        'private' => [
            'driver' => 'local',
            'root' => storage_path('app/private'),
            'serve' => false,
            'throw' => true,
            'visibility' => 'private',
        ],

        // Only for intentionally public assets (doctor photo, published article images).
        'public' => [
            'driver' => 'local',
            'root' => storage_path('app/public'),
            'url' => rtrim(env('APP_URL', 'http://localhost'), '/').'/storage',
            'visibility' => 'public',
            'throw' => true,
        ],
    ],

    'links' => [
        public_path('storage') => storage_path('app/public'),
    ],
];
