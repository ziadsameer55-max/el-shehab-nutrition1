<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\PatientProfile;
use App\Models\User;
use App\Services\AuditLogger;
use App\Support\Settings;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /** POST /api/auth/register: creates a patient account + empty patient profile and signs them in. */
    public function register(RegisterRequest $request): JsonResponse
    {
        $data = $request->validated();

        try {
            $user = DB::transaction(function () use ($data) {
                $user = new User;
                $user->fill([
                    'name' => $data['name'],
                    'email' => $data['email'],
                    'phone' => $data['phone'],
                    'password' => $data['password'],
                    'locale' => $data['locale'],
                ]);
                $user->role = User::ROLE_PATIENT;
                $user->save();

                // Single-doctor system: the patient is linked to the (only) active doctor.
                $doctorId = User::query()
                    ->where('role', User::ROLE_DOCTOR)
                    ->where('is_active', true)
                    ->orderBy('created_at')
                    ->value('id');

                PatientProfile::create([
                    'user_id' => $user->id,
                    'primary_doctor_id' => $doctorId,
                    'privacy_accepted_at' => now(),
                    'consent_version' => Settings::get('consent_version', '1.0'),
                ]);

                return $user;
            });
        } catch (UniqueConstraintViolationException) {
            // Two simultaneous sign-ups with the same email: the database index is the final arbiter.
            throw ValidationException::withMessages([
                'email' => __('validation.unique', ['attribute' => __('validation.attributes.email')]),
            ]);
        }

        Auth::guard('web')->login($user);
        $request->session()->regenerate();

        AuditLogger::record('user.registered', $user, null, ['role' => $user->role], null, $user);

        return (new UserResource($user->load('patientProfile')))
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }

    /** POST /api/auth/login */
    public function login(LoginRequest $request): UserResource
    {
        $request->authenticate();
        $request->session()->regenerate();

        /** @var User $user */
        $user = Auth::guard('web')->user();
        $user->forceFill(['last_login_at' => now()])->saveQuietly();

        AuditLogger::record('auth.login', $user, null, null, null, $user);

        return new UserResource($user->load('patientProfile'));
    }

    /** GET /api/auth/me */
    public function me(Request $request): UserResource
    {
        return new UserResource($request->user()->loadMissing('patientProfile'));
    }

    /** PATCH /api/auth/locale: remembers the language used for emails and notifications. */
    public function updateLocale(Request $request): UserResource
    {
        $data = $request->validate(['locale' => ['required', 'in:ar,en']]);

        $user = $request->user();
        $user->forceFill(['locale' => $data['locale']])->saveQuietly();

        return new UserResource($user->loadMissing('patientProfile'));
    }

    /** POST /api/auth/logout */
    public function logout(Request $request): Response
    {
        Auth::guard('web')->logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return response()->noContent();
    }
}
