<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureAdminPage
{
    protected array $map = [
        'overview' => 'dashboard',
        'stats' => 'dashboard',
        'packages' => 'catalog',
        'practice-areas' => 'catalog',
        'cache' => 'catalog',
        'tracks' => 'learning',
        'subjects' => 'learning',
        'profiles' => 'profiles',
        'questions' => 'questions',
        'lessons' => 'lessons',
        'accounts' => 'students',
        'payments' => 'payments',
        'pending-payments' => 'payments',
        'kyc' => 'approvals',
        'pending-tutors' => 'approvals',
        'tutors' => 'approvals',
        'staff' => 'staff',
        'mail' => 'mail',
    ];

    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();
        if ($user?->role !== 'admin') {
            abort(403, 'Admin only.');
        }

        $parts = explode('/', trim($request->path(), '/'));
        $segment = $parts[2] ?? '';
        $page = $this->map[$segment] ?? null;
        if ($page && ! $user->canOpenAdmin($page)) {
            abort(403, 'This page is not assigned to this staff account.');
        }

        return $next($request);
    }
};
