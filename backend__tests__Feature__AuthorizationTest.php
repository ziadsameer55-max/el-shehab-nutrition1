<?php

namespace Tests\Feature;

use App\Models\User;
use App\Support\PatientAccess;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class AuthorizationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Route::middleware(['api', 'auth:sanctum', 'role:doctor'])
            ->get('/api/_test/doctor-only', fn () => response()->json(['ok' => true]));
        Route::middleware(['api', 'auth:sanctum', 'role:patient'])
            ->get('/api/_test/patient-only', fn () => response()->json(['ok' => true]));
    }

    // ---- role middleware ----

    public function test_guest_is_rejected_with_401(): void
    {
        $this->spa()->getJson('/api/_test/doctor-only')->assertUnauthorized();
    }

    public function test_patient_cannot_reach_doctor_routes(): void
    {
        $patient = User::factory()->withProfile()->create();

        $this->actingAs($patient, 'web')->spa()->getJson('/api/_test/doctor-only')->assertForbidden();
    }

    public function test_doctor_cannot_reach_patient_only_routes(): void
    {
        $doctor = User::factory()->doctor()->create();

        $this->actingAs($doctor, 'web')->spa()->getJson('/api/_test/patient-only')->assertForbidden();
    }

    public function test_doctor_can_reach_doctor_routes(): void
    {
        $doctor = User::factory()->doctor()->create();

        $this->actingAs($doctor, 'web')->spa()->getJson('/api/_test/doctor-only')->assertOk();
    }

    public function test_disabled_doctor_is_refused(): void
    {
        $doctor = User::factory()->doctor()->inactive()->create();

        $this->actingAs($doctor, 'web')->spa()->getJson('/api/_test/doctor-only')->assertForbidden();
    }

    // ---- patient data access (spec: a patient must never open another patient's data) ----

    public function test_patient_can_access_only_their_own_data(): void
    {
        $a = User::factory()->withProfile()->create();
        $b = User::factory()->withProfile()->create();

        $this->assertTrue(PatientAccess::allows($a, $a));
        $this->assertFalse(PatientAccess::allows($a, $b));
        $this->assertFalse(PatientAccess::allows($b, $a));
    }

    public function test_doctor_can_access_only_their_own_patients(): void
    {
        $doctor = User::factory()->doctor()->create();
        $otherDoctor = User::factory()->doctor()->create();
        $mine = User::factory()->withProfile($doctor)->create();
        $theirs = User::factory()->withProfile($otherDoctor)->create();
        $unassigned = User::factory()->withProfile()->create();

        $this->assertTrue(PatientAccess::allows($doctor, $mine));
        $this->assertFalse(PatientAccess::allows($doctor, $theirs));
        $this->assertFalse(PatientAccess::allows($doctor, $unassigned));
    }

    public function test_disabled_users_and_non_patients_are_never_accessible(): void
    {
        $doctor = User::factory()->doctor()->create();
        $disabledDoctor = User::factory()->doctor()->inactive()->create();
        $patient = User::factory()->withProfile($doctor)->create();
        $disabledPatient = User::factory()->withProfile($doctor)->inactive()->create();

        $this->assertFalse(PatientAccess::allows($disabledDoctor, $patient));
        $this->assertFalse(PatientAccess::allows($disabledPatient, $disabledPatient));
        $this->assertFalse(PatientAccess::allows($doctor, $doctor)); // a doctor is not a patient record
    }

    public function test_gate_is_registered_for_controllers(): void
    {
        $doctor = User::factory()->doctor()->create();
        $mine = User::factory()->withProfile($doctor)->create();
        $other = User::factory()->withProfile()->create();

        $this->assertTrue(Gate::forUser($doctor)->allows('access-patient', $mine));
        $this->assertTrue(Gate::forUser($doctor)->denies('access-patient', $other));
        $this->assertTrue(Gate::forUser($doctor)->allows('doctor-only'));
        $this->assertTrue(Gate::forUser($mine)->denies('doctor-only'));
    }
}
