<?php

use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\Auth\PasswordController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| EL SHEHAB NUTRITION API: Developed & Powered by CODING Systems
|--------------------------------------------------------------------------
| Cookie-based Sanctum SPA authentication. Every protected route is authorized on the server
| (auth:sanctum + role middleware / policies), never only hidden in the UI.
*/

Route::prefix('auth')->group(function () {
    Route::middleware('throttle:auth')->group(function () {
        Route::post('register', [AuthController::class, 'register']);
        Route::post('login', [AuthController::class, 'login']);
        Route::post('forgot-password', [PasswordController::class, 'forgot']);
        Route::post('reset-password', [PasswordController::class, 'reset']);
    });

    Route::middleware('auth:sanctum')->group(function () {
        Route::get('me', [AuthController::class, 'me']);
        Route::patch('locale', [AuthController::class, 'updateLocale']);
        Route::post('logout', [AuthController::class, 'logout']);
    });
});
