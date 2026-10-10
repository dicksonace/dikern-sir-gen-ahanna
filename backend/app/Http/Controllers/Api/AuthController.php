<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Support\AccountMailer;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
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
        $request->validate([
            'email' => [
                Rule::unique('users', 'email')->where(fn ($query) => $query->where('division', $division)),
            ],
        ], [
            'email.unique' => $division === 'law'
                ? 'This email already has a Law advice account. Sign in on that tab, or use Learning for the other side.'
                : 'This email already has a Learning account. Sign in on that tab, or use Law advice for the other side.',
        ]);

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
            $this->confirmEmailCode($request);
            $ok = true;
            $message = 'This account is confirmed. Go back to the app and sign in.';
        } catch (ValidationException) {
            $ok = false;
            $message = 'That confirmation link has expired or was already used. Ask for a new code in the app.';
        }

        return response()->view('email-verified', [
            'ok' => $ok,
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

        if ($user && $user->role !== 'admin' && $user->email_verified_at === null) {
            AccountMailer::queueVerification($user);
        }

        return response()->json([
            'message' => 'If that account is still waiting, a new confirmation code is on the way.',
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
                'email' => ['Confirm your email first. We sent a code to this address.'],
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
            $request->user()->load(['tutorProfile.subjects', 'identityDocument'])
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

        $user = User::where('email', $data['email'])->where('division', $data['division'])->first();
        $row = $user
            ? DB::table('email_verification_codes')->where('email', AccountMailer::key($user))->first()
            : null;
        $created = $row?->created_at ? \Illuminate\Support\Carbon::parse($row->created_at) : null;
        $fresh = $created && $created->greaterThan(now()->subMinutes(60));

        if (! $user || ! $row || ! $fresh || ! Hash::check($data['code'], $row->token)) {
            throw ValidationException::withMessages([
                'code' => ['That confirmation code is not valid.'],
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

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out']);
    }
}
