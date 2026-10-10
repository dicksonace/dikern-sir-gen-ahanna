<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\IdentityDocument;
use App\Models\Lesson;
use App\Models\Payment;
use App\Models\Question;
use App\Models\Subject;
use App\Models\Track;
use App\Models\TutorProfile;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AdminController extends Controller
{
    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password) || $user->role !== 'admin') {
            throw ValidationException::withMessages([
                'email' => ['Admin sign-in only. Everyone else uses the mobile app.'],
            ]);
        }

        $token = $user->createToken('admin-web')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $user,
        ]);
    }

    public function overview()
    {
        $pending = TutorProfile::with('user:id,name,email,role,division')
            ->where('status', 'pending')
            ->latest()
            ->limit(8)
            ->get();

        return response()->json([
            'learning' => [
                'students' => User::where('role', 'student')->count(),
                'tutors' => User::where('role', 'tutor')->count(),
                'lecturers' => User::where('role', 'lecturer')->count(),
            ],
            'law' => [
                'clients' => User::where('role', 'client')->count(),
                'lawyers' => User::where('role', 'lawyer')->count(),
                'counsel' => User::where('role', 'counsel')->count(),
            ],
            'pending_profiles' => TutorProfile::where('status', 'pending')->count(),
            'pending_kyc' => IdentityDocument::where('status', 'pending')->count(),
            'pending_payments' => Payment::where('status', 'pending')->count(),
            'open_questions' => Question::where('status', 'open')->count(),
            'pending' => $pending,
            'charts' => $this->charts(),
        ]);
    }

    protected function charts(): array
    {
        $questionCounts = Question::query()
            ->whereNotNull('subject_id')
            ->selectRaw('subject_id, count(*) as total')
            ->groupBy('subject_id')
            ->pluck('total', 'subject_id');

        $tracks = Track::query()
            ->with(['subjects' => function ($query) {
                $query->withCount([
                    'tutorProfiles as approved_tutors' => fn ($q) => $q->where('status', 'approved'),
                ])->orderBy('name');
            }])
            ->where('division', 'tutor')
            ->where('is_active', true)
            ->orderBy('sort_order')
            ->get()
            ->map(function (Track $track) use ($questionCounts) {
                return [
                    'name' => $track->name,
                    'slug' => $track->slug,
                    'kind' => $track->kind,
                    'subjects' => $track->subjects->map(fn (Subject $subject) => [
                        'name' => $subject->name,
                        'slug' => $subject->slug,
                        'tutors' => (int) $subject->approved_tutors,
                        'questions' => (int) ($questionCounts[$subject->id] ?? 0),
                    ])->values(),
                ];
            })
            ->values();

        $areas = Subject::query()
            ->where('division', 'law')
            ->withCount([
                'tutorProfiles as approved_people' => fn ($q) => $q->where('status', 'approved'),
            ])
            ->orderBy('name')
            ->get()
            ->map(fn (Subject $subject) => [
                'name' => $subject->name,
                'slug' => $subject->slug,
                'people' => (int) $subject->approved_people,
                'questions' => (int) ($questionCounts[$subject->id] ?? 0),
            ])
            ->values();

        return [
            'people' => [
                ['label' => 'Students', 'value' => User::where('role', 'student')->count(), 'side' => 'learning'],
                ['label' => 'Tutors', 'value' => User::where('role', 'tutor')->count(), 'side' => 'learning'],
                ['label' => 'Lecturers', 'value' => User::where('role', 'lecturer')->count(), 'side' => 'learning'],
                ['label' => 'Clients', 'value' => User::where('role', 'client')->count(), 'side' => 'law'],
                ['label' => 'Lawyers', 'value' => User::where('role', 'lawyer')->count(), 'side' => 'law'],
                ['label' => 'Legal counsel', 'value' => User::where('role', 'counsel')->count(), 'side' => 'law'],
            ],
            'tracks' => $tracks,
            'law_areas' => $areas,
            'questions' => $this->statusCounts(Question::class),
            'lessons' => $this->statusCounts(Lesson::class),
            'payments' => Payment::query()
                ->selectRaw('status, count(*) as value, coalesce(sum(amount), 0) as amount')
                ->groupBy('status')
                ->orderByDesc('value')
                ->get()
                ->map(fn ($row) => [
                    'label' => (string) $row->status,
                    'value' => (int) $row->value,
                    'amount' => (float) $row->amount,
                ])
                ->values(),
        ];
    }

    protected function statusCounts(string $model): array
    {
        return $model::query()
            ->selectRaw('status, count(*) as value')
            ->groupBy('status')
            ->orderByDesc('value')
            ->get()
            ->map(fn ($row) => [
                'label' => (string) $row->status,
                'value' => (int) $row->value,
            ])
            ->values()
            ->all();
    }
}
