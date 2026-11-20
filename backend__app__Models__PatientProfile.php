<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PatientProfile extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'user_id', 'primary_doctor_id', 'date_of_birth', 'gender', 'city', 'country',
        'height_cm', 'target_weight_kg', 'goal', 'activity_level',
        'medical_conditions', 'allergies', 'medications', 'dietary_preferences', 'notes',
        'emergency_contact_name', 'emergency_contact_phone',
        'health_completed_at', 'consent_version', 'privacy_accepted_at', 'health_consent_at',
    ];

    protected function casts(): array
    {
        return [
            'date_of_birth' => 'date',
            'height_cm' => 'decimal:1',
            'target_weight_kg' => 'decimal:1',
            'health_completed_at' => 'datetime',
            'privacy_accepted_at' => 'datetime',
            'health_consent_at' => 'datetime',
            // Sensitive health text is encrypted at rest (so it cannot be searched in SQL by design).
            'medical_conditions' => 'encrypted',
            'allergies' => 'encrypted',
            'medications' => 'encrypted',
            'dietary_preferences' => 'encrypted',
            'notes' => 'encrypted',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function primaryDoctor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'primary_doctor_id');
    }
}
