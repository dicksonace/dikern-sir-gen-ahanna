<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\AccountMailer;
use App\Support\ReadCache;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:120',
            'email' => 'required|email',
            'password' => 'required|string|min:6|confirmed',
            'role' => 'required|in:student,tutor,lecturer,client,lawyer,counsel',
            'phone' => 'nullable|string|max:30',
        ]);

        $division = User::divisionForRole($data['role']);
        $existing = User::where('email', $data['email'])
            ->where('division', $division)
            ->with('tutorProfile:id,user_id,status')
            ->first();
        if ($existing) {
            throw ValidationException::withMessages([
                'email' => [$this->existingAccountMessage($existing)],
            ]);
        }

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => $data['password'],
            'role' => $data['role'],
            'division' => $division,
            'phone' => $data['phone'] ?? null,
        ]);

        if (in_array($user->role, User::PROVIDER_ROLES, true)) {
            $user->tutorProfile()->create([
                'status' => 'pending',
                'bio' => 'New profile awaiting approval',
            ]);
        }

        $code = AccountMailer::queueVerification($user);

        $payload = [
            'verification_required' => true,
            'message' => 'Account created. Confirm the code we emailed you, then sign in.',
            'email' => $user->email,
            'division' => $user->division,
        ];

        if (app()->environment('local')) {
            $payload['verification_code'] = $code;
        }

        return response()->json($payload, 201);
    }

    public function verifyEmail(Request $request)
    {
        $user = $this->confirmEmailCode($request);

        return response()->json([
            'message' => 'Email confirmed. Sign in with your password.',
            'user' => $user,
        ]);
    }

    public function verifyEmailPage(Request $request)
    {
        try {
            $user = $this->confirmEmailCode($request);
            $ok = true;
            $title = 'Email confirmed';
            $message = 'This account is confirmed. Go back to the app and sign in.';
            $waiting = $this->approvalSentence($user);
            if ($waiting) {
                $message .= ' '.$waiting;
            }
        } catch (ValidationException $exception) {
            $ok = false;
            $message = collect($exception->errors())->flatten()->first()
                ?? 'That code did not work.';
            $title = str_contains($message, 'expired')
                ? 'Code expired'
                : (str_contains($message, 'already used') ? 'Code already used' : 'Code did not match');
        }

        return response()->view('email-verified', [
            'ok' => $ok,
            'title' => $title,
            'message' => $message,
        ]);
    }

    public function resendVerification(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'division' => 'required|in:tutor,law',
        ]);

        $user = User::where('email', $data['email'])->where('division', $data['division'])->first();

        if ($user && $user->role !== 'admin') {
            $user->load('tutorProfile:id,user_id,status');
            if ($user->email_verified_at !== null) {
                throw ValidationException::withMessages([
                    'email' => [$this->usedCodeMessage($user)],
                ]);
            }

            AccountMailer::queueVerification($user);
        }

        return response()->json([
            'message' => 'A new code is on the way. It expires in 60 minutes.',
        ]);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
            'division' => 'required|in:tutor,law',
        ]);

        $user = User::where('email', $data['email'])->where('division', $data['division'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            $other = User::where('email', $data['email'])
                ->where('division', $data['division'] === 'law' ? 'tutor' : 'law')
                ->exists();

            throw ValidationException::withMessages([
                'email' => [$other
                    ? ($data['division'] === 'law'
                        ? 'This email is on Learning. Switch the tab to sign in there.'
                        : 'This email is on Law advice. Switch the tab to sign in there.')
                    : 'Invalid credentials.'],
            ]);
        }

        if ($user->role === 'admin') {
            throw ValidationException::withMessages([
                'email' => ['Admin accounts sign in on the website, not the app.'],
            ]);
        }

        if ($user->email_verified_at === null) {
            throw ValidationException::withMessages([
                'email' => ['This email is not confirmed yet. Enter the code from the email, or send a new one.'],
            ]);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $user->load('tutorProfile.subjects'),
        ]);
    }

    public function me(Request $request)
    {
        return response()->json(
            $request->user()->load([
                'tutorProfile:id,user_id,bio,qualifications,experience,satisfaction_points,status,available_slots,commission_rate',
                'tutorProfile.subjects:id,name,slug',
                'identityDocument' => fn ($query) => $query->forAccount(),
            ])
        );
    }

    public function updateProfile(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:120',
            'phone' => 'nullable|string|max:30',
            'bio' => 'nullable|string|max:1000',
            'qualifications' => 'nullable|string|max:255',
            'experience' => 'nullable|string|max:255',
        ]);

        $user = $request->user();
        $user->update([
            'name' => $data['name'],
            'phone' => $data['phone'] ?? null,
        ]);

        if ($user->tutorProfile) {
            $user->tutorProfile->update([
                'bio' => $data['bio'] ?? $user->tutorProfile->bio,
                'qualifications' => $data['qualifications'] ?? null,
                'experience' => $data['experience'] ?? null,
            ]);
        }

        ReadCache::bump('tutors');

        return response()->json($user->fresh()->load('tutorProfile.subjects'));
    }

    public function changePassword(Request $request)
    {
        $data = $request->validate([
            'current_password' => 'required|string',
            'password' => 'required|string|min:6|confirmed',
        ]);

        $user = $request->user();

        if (! Hash::check($data['current_password'], $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['Current password is wrong.'],
            ]);
        }

        $user->update(['password' => $data['password']]);
        AccountMailer::queuePasswordChanged($user);

        return response()->json(['message' => 'Password updated.']);
    }

    public function forgotPassword(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'division' => 'required|in:tutor,law',
        ]);

        $user = User::where('email', $data['email'])->where('division', $data['division'])->first();
        $payload = [
            'message' => 'If that email has an account on this side, use the reset code to choose a new password.',
        ];

        if ($user && $user->role !== 'admin') {
            $code = (string) random_int(100000, 999999);
            DB::table('password_reset_tokens')->updateOrInsert(
                ['email' => $this->resetKey($user->email, $user->division)],
                ['token' => Hash::make($code), 'created_at' => now()]
            );

            AccountMailer::queuePasswordReset($user, $code);

            if (app()->environment('local')) {
                $payload['reset_code'] = $code;
            }
        }

        return response()->json($payload);
    }

    public function resetPassword(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'division' => 'required|in:tutor,law',
            'code' => 'required|string',
            'password' => 'required|string|min:6|confirmed',
        ]);

        $row = DB::table('password_reset_tokens')->where('email', $this->resetKey($data['email'], $data['division']))->first();
        $created = $row?->created_at ? \Illuminate\Support\Carbon::parse($row->created_at) : null;
        $fresh = $created && $created->greaterThan(now()->subMinutes(30));

        if (! $row || ! $fresh || ! Hash::check($data['code'], $row->token)) {
            throw ValidationException::withMessages([
                'code' => ['That reset code is not valid.'],
            ]);
        }

        $user = User::where('email', $data['email'])->where('division', $data['division'])->where('role', '!=', 'admin')->first();
        if (! $user) {
            throw ValidationException::withMessages([
                'email' => ['That reset code is not valid.'],
            ]);
        }

        $user->update(['password' => $data['password']]);
        DB::table('password_reset_tokens')->where('email', $this->resetKey($data['email'], $data['division']))->delete();
        AccountMailer::queuePasswordChanged($user);

        return response()->json(['message' => 'Password reset. Sign in with the new password.']);
    }

    protected function confirmEmailCode(Request $request): User
    {
        $data = $request->validate([
            'email' => 'required|email',
            'division' => 'required|in:tutor,law',
            'code' => 'required|string',
        ]);

        $code = trim($data['code']);
        $user = User::where('email', $data['email'])->where('division', $data['division'])->first();
        if ($user) {
            $user->load('tutorProfile:id,user_id,status');
        }
        if ($user && $user->email_verified_at !== null) {
            throw ValidationException::withMessages([
                'code' => [$this->usedCodeMessage($user)],
            ]);
        }

        $row = $user
            ? DB::table('email_verification_codes')->where('email', AccountMailer::key($user))->first()
            : null;
        $created = $row?->created_at ? \Illuminate\Support\Carbon::parse($row->created_at) : null;
        $fresh = $created && $created->greaterThan(now()->subMinutes(60));

        if (! $user || ! $row) {
            throw ValidationException::withMessages([
                'code' => ['There is no code waiting for this account. Tap Send the code again.'],
            ]);
        }

        if (! $fresh) {
            throw ValidationException::withMessages([
                'code' => ['This code has expired. Tap Send the code again.'],
            ]);
        }

        if (! Hash::check($code, $row->token)) {
            throw ValidationException::withMessages([
                'code' => ['That code does not match the email. Check the digits, or tap Send the code again.'],
            ]);
        }

        $user->forceFill(['email_verified_at' => now()])->save();
        DB::table('email_verification_codes')->where('email', AccountMailer::key($user))->delete();

        return $user->fresh();
    }

    protected function resetKey(string $email, string $division): string
    {
        return strtolower($email).'|'.$division;
    }

    protected function existingAccountMessage(User $user): string
    {
        $side = $user->division === 'law' ? 'Law advice' : 'Learning';
        if ($user->email_verified_at === null) {
            return "This {$side} account is still waiting for its email code. Enter the code below, or send a new one.";
        }

        $waiting = $this->approvalSentence($user);

        return $waiting
            ? "This email already has a {$side} account. Sign in. {$waiting}"
            : "This email already has a {$side} account. Sign in on this tab.";
    }

    protected function usedCodeMessage(User $user): string
    {
        $waiting = $this->approvalSentence($user);

        return $waiting
            ? "This code was already used. The email is confirmed. Sign in. {$waiting}"
            : 'This code was already used. The email is confirmed. Sign in.';
    }

    protected function approvalSentence(User $user): ?string
    {
        if (! in_array($user->role, User::PROVIDER_ROLES, true)) {
            return null;
        }

        $status = $user->tutorProfile?->status ?? 'pending';
        $role = match ($user->role) {
            'lecturer' => 'lecturer',
            'lawyer' => 'lawyer',
            'counsel' => 'legal counsel',
            default => 'tutor',
        };

        return match ($status) {
            'rejected' => "An admin did not approve this {$role} profile.",
            'approved' => null,
            default => "This {$role} profile is waiting for an admin to approve it.",
        };
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out']);
    }
}
