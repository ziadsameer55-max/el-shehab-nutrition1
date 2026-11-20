<?php

namespace App\Notifications;

use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Notifications\Messages\MailMessage;

/** Password-reset email in the user's language, linking to the Next.js reset page. */
class ResetPasswordNotification extends ResetPassword
{
    public function toMail($notifiable): MailMessage
    {
        $locale = in_array($notifiable->locale ?? null, config('esn.locales'), true)
            ? $notifiable->locale
            : config('esn.default_locale');

        // Arabic is the default language and has no URL prefix; English lives under /en.
        $prefix = $locale === config('esn.default_locale') ? '' : '/'.$locale;

        $url = config('esn.frontend_url').$prefix.'/reset-password?'.http_build_query([
            'token' => $this->token,
            'email' => $notifiable->getEmailForPasswordReset(),
        ]);

        $minutes = config('auth.passwords.'.config('auth.defaults.passwords').'.expire');

        return (new MailMessage)
            ->subject(__('mail.reset.subject'))
            ->greeting(__('mail.reset.greeting', ['name' => $notifiable->name]))
            ->line(__('mail.reset.intro'))
            ->action(__('mail.reset.action'), $url)
            ->line(__('mail.reset.expires', ['count' => $minutes]))
            ->line(__('mail.reset.ignore'))
            ->salutation(__('mail.salutation'));
    }
}
