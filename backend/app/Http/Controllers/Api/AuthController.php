<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:120',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|string|min:6',
            'role' => 'required|in:student,tutor,lecturer,client,lawyer,counsel',
            'phone' => 'nullable|string|max:30',
        ]);

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => $data['password'],
            'role' => $data['role'],
            'division' => User::divisionForRole($data['role']),
            'phone' => $data['phone'] ?? null,
        ]);

        if (in_array($user->role, User::PROVIDER_ROLES, true)) {
            $user->tutorProfile()->create([
                'status' => 'pending',
                'bio' => 'New profile awaiting approval',
            ]);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $user->load('tutorProfile'),
        ], 201);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Invalid credentials.'],
            ]);
        }

        if ($user->role === 'admin') {
            throw ValidationException::withMessages([
                'email' => ['Admin accounts sign in on the website, not the app.'],
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
            $request->user()->load('tutorProfile.subjects')
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

        return response()->json(['message' => 'Password updated.']);
    }

    public function forgotPassword(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
        ]);

        $user = User::where('email', $data['email'])->first();
        $payload = [
            'message' => 'If that email has an account, use the reset code to choose a new password.',
        ];

        if ($user && $user->role !== 'admin') {
            $code = (string) random_int(100000, 999999);
            DB::table('password_reset_tokens')->updateOrInsert(
                ['email' => $user->email],
                ['token' => Hash::make($code), 'created_at' => now()]
            );

            try {
                Mail::raw(
                    "Your සර් ගෙන් අහන්න reset code is {$code}. It expires in 30 minutes.",
                    fn ($message) => $message->to($user->email)->subject('Reset your password')
                );
            } catch (\Throwable) {
                // A missing mailbox should not block the reset code.
            }

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
            'code' => 'required|string',
            'password' => 'required|string|min:6|confirmed',
        ]);

        $row = DB::table('password_reset_tokens')->where('email', $data['email'])->first();
        $created = $row?->created_at ? \Illuminate\Support\Carbon::parse($row->created_at) : null;
        $fresh = $created && $created->greaterThan(now()->subMinutes(30));

        if (! $row || ! $fresh || ! Hash::check($data['code'], $row->token)) {
            throw ValidationException::withMessages([
                'code' => ['That reset code is not valid.'],
            ]);
        }

        $user = User::where('email', $data['email'])->where('role', '!=', 'admin')->first();
        if (! $user) {
            throw ValidationException::withMessages([
                'email' => ['That reset code is not valid.'],
            ]);
        }

        $user->update(['password' => $data['password']]);
        DB::table('password_reset_tokens')->where('email', $data['email'])->delete();

        return response()->json(['message' => 'Password reset. Sign in with the new password.']);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out']);
    }
}
