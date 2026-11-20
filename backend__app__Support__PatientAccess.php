<?php

namespace App\Support;

use App\Models\User;

/**
 * Single source of truth for "may this user see this patient's data?" (spec section 7.2).
 * Every patient-owned resource (profile, files, appointments, payments, plans, progress) must go
 * through the `access-patient` gate that wraps this class: never trust an ID taken from the URL.
 */
final class PatientAccess
{
    public static function allows(User $actor, User $patient): bool
    {
        if (! $actor->is_active || ! $patient->isPatient()) {
            return false;
        }

        // A patient: only their own records.
        if ($actor->isPatient()) {
            return $actor->is($patient);
        }

        // A doctor: only their own patients.
        if ($actor->isDoctor()) {
            $patient->loadMissing('patientProfile');

            return $patient->patientProfile !== null
                && $patient->patientProfile->primary_doctor_id === $actor->id;
        }

        return false;
    }
}
