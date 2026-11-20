<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** The only shape in which a user leaves the API. No password, token or internal flags. */
class UserResource extends JsonResource
{
    public static $wrap = null;

    public function toArray(Request $request): array
    {
        $isPatient = $this->role === 'patient';

        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone,
            'role' => $this->role,
            'locale' => $this->locale,
            // Drives the "complete your health profile" prompt after registration (null for the doctor).
            'health_profile_completed' => $isPatient
                ? (bool) $this->patientProfile?->health_completed_at
                : null,
        ];
    }
}
