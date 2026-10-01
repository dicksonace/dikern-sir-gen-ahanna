<?php

namespace App\Http\Controllers;

use App\Models\TutorProfile;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;

class AdminWebController extends Controller
{
    public function showLogin()
    {
        if (Auth::check() && Auth::user()->role === 'admin') {
            return redirect()->route('admin.dashboard');
        }

        return view('admin.login');
    }

    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        if (! Auth::attempt($credentials, $request->boolean('remember'))) {
            throw ValidationException::withMessages([
                'email' => 'Those details do not match an admin account.',
            ]);
        }

        if (Auth::user()->role !== 'admin') {
            Auth::logout();
            throw ValidationException::withMessages([
                'email' => 'This website is for administrators only.',
            ]);
        }

        $request->session()->regenerate();

        return redirect()->route('admin.dashboard');
    }

    public function dashboard()
    {
        $this->ensureAdmin();
        $users = User::query()
            ->where('role', '!=', 'admin')
            ->orderBy('division')
            ->orderBy('role')
            ->orderBy('name')
            ->get();

        $pending = TutorProfile::with('user')
            ->where('status', 'pending')
            ->latest()
            ->get();

        $counts = [
            'tutor' => [
                'student' => $users->where('role', 'student')->count(),
                'tutor' => $users->where('role', 'tutor')->count(),
                'lecturer' => $users->where('role', 'lecturer')->count(),
            ],
            'law' => [
                'client' => $users->where('role', 'client')->count(),
                'lawyer' => $users->where('role', 'lawyer')->count(),
                'counsel' => $users->where('role', 'counsel')->count(),
            ],
        ];

        return view('admin.dashboard', compact('users', 'pending', 'counts'));
    }

    public function approve(TutorProfile $profile)
    {
        $this->ensureAdmin();
        $profile->update(['status' => 'approved']);

        return back()->with('status', $profile->user?->name.' is approved.');
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    }

    protected function ensureAdmin(): void
    {
        if (Auth::user()?->role !== 'admin') {
            abort(403);
        }
    }
}
