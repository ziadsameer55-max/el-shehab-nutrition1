<?php

namespace App\Http\Requests\Auth;

use App\Models\User;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'name' => is_string($this->name) ? trim(preg_replace('/\s+/u', ' ', $this->name)) : $this->name,
            'email' => is_string($this->email) ? mb_strtolower(trim($this->email)) : $this->email,
            'phone' => is_string($this->phone) ? $this->normalizePhone($this->phone) : $this->phone,
            'locale' => $this->input('locale', app()->getLocale()),
        ]);
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'min:2', 'max:150'],
            'email' => [
                'required', 'string', 'email:rfc', 'max:255',
                // case-insensitive uniqueness, matching the lower(email) unique index
                function (string $attribute, mixed $value, \Closure $fail) {
                    if (User::query()->whereRaw('lower(email) = ?', [mb_strtolower((string) $value)])->exists()) {
                        $fail(__('validation.unique', ['attribute' => __('validation.attributes.email')]));
                    }
                },
            ],
            'phone' => ['required', 'string', 'regex:/^\+?[0-9]{7,15}$/'],
            'password' => ['required', 'string', 'confirmed', Password::defaults()],
            'locale' => ['required', 'in:ar,en'],
            // Explicit privacy-policy acceptance is required to create an account (spec section 7.2).
            'accepted_privacy' => ['accepted'],
        ];
    }

    /** Remove spaces/dashes/brackets and convert Arabic-Indic digits so "٠١٠ ١٢٣..." is accepted. */
    private function normalizePhone(string $phone): string
    {
        $phone = strtr($phone, [
            '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4',
            '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
        ]);

        return preg_replace('/[\s\-().]/', '', $phone) ?? $phone;
    }
}
