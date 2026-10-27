<?php

namespace App\Support;

use App\Models\User;
use App\Notifications\AccountMail;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class AccountMailer
{
    public static function side(User $user): string
    {
        return $user->division === 'law' ? 'Law advice' : 'Learning';
    }

    public static function send(User $user, string $subject, string $greeting, array $lines, ?string $actionText = null, ?string $actionUrl = null): void
    {
        $user->notify(new AccountMail($subject, $greeting, $lines, $actionText, $actionUrl));
    }

    public static function queueVerification(User $user): string
    {
        $code = (string) random_int(100000, 999999);

        DB::table('email_verification_codes')->updateOrInsert(
            ['email' => self::key($user)],
            ['token' => Hash::make($code), 'created_at' => now()]
        );

        $link = url('/email/verify?'.http_build_query([
            'email' => $user->email,
            'division' => $user->division,
            'code' => $code,
        ]));

        self::send(
            $user,
            'Confirm your email',
            'Hello '.$user->name.',',
            [
                'Confirm the '.self::side($user).' account for '.$user->email.'.',
                'Your code is '.$code.'. It expires in 60 minutes.',
                'You can enter that code in the app, or open the button in this email.',
            ],
            'Confirm email',
            $link,
        );

        return $code;
    }

    public static function queuePasswordReset(User $user, string $code): void
    {
        self::send(
            $user,
            'Reset your password',
            'Hello '.$user->name.',',
            [
                'A password reset was requested for the '.self::side($user).' account '.$user->email.'.',
                'Your code is '.$code.'. It expires in 30 minutes.',
                'If you did not ask for this, you can ignore the email.',
            ],
        );
    }

    public static function queuePasswordChanged(User $user): void
    {
        self::send(
            $user,
            'Your password was changed',
            'Hello '.$user->name.',',
            [
                'The password for your '.self::side($user).' account was just changed.',
                'If that was not you, reset the password from the sign-in screen.',
            ],
        );
    }

    public static function queueKycReceived(User $user): void
    {
        self::send(
            $user,
            'We received your identity document',
            'Hello '.$user->name.',',
            [
                'Your identity document is with the admin team.',
                'You will get another email when it is approved or if we need a clearer copy.',
            ],
        );
    }

    public static function queueKycForAdmins(User $subject): void
    {
        $admins = User::where('role', 'admin')->get();
        foreach ($admins as $admin) {
            self::send(
                $admin,
                'Identity document to review',
                'Hello '.$admin->name.',',
                [
                    $subject->name.' ('.$subject->email.') uploaded an identity document on the '.self::side($subject).' side.',
                    'Open the admin website and review it under Identity documents.',
                ],
            );
        }
    }

    public static function queueKycDecision(User $user, string $status, ?string $note): void
    {
        $approved = $status === 'approved';
        self::send(
            $user,
            $approved ? 'Your identity document was approved' : 'Your identity document needs another try',
            'Hello '.$user->name.',',
            $approved
                ? ['The admin team approved your identity document.']
                : [
                    'The admin team could not accept this identity document.',
                    $note ? 'Note: '.$note : 'Upload a clearer copy from your profile.',
                ],
        );
    }

    public static function queueProfileApproved(User $user): void
    {
        self::send(
            $user,
            'Your profile is approved',
            'Hello '.$user->name.',',
            [
                'Your '.self::side($user).' profile is approved.',
                'People on that side can now find you in the app.',
            ],
        );
    }

    public static function queueStaffWelcome(User $user): void
    {
        self::send(
            $user,
            'Your admin desk login',
            'Hello '.$user->name.',',
            [
                'A staff account was created for you on the සර් ගෙන් අහන්න admin website.',
                'Sign in with '.$user->email.' and the password you were given in person.',
                'Open your profile on the website to change that password.',
            ],
            'Open admin',
            'https://admin.sirgenahanna.com/login',
        );
    }

    public static function queuePaymentVerified(User $user, string $packageName): void
    {
        self::send(
            $user,
            'Your payment is verified',
            'Hello '.$user->name.',',
            [
                'The payment for '.$packageName.' is verified.',
                'The package is active on your account.',
            ],
        );
    }

    public static function key(User $user): string
    {
        return strtolower($user->email).'|'.$user->division;
    }
}
