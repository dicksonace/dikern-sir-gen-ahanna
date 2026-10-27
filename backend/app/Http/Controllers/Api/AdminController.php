<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commission;
use App\Models\IdentityDocument;
use App\Models\Lesson;
use App\Models\Package;
use App\Models\Payment;
use App\Models\Question;
use App\Models\Subject;
use App\Models\Subscription;
use App\Models\Track;
use App\Models\TutorProfile;
use App\Models\User;
use App\Support\AccountMailer;
use App\Support\ReadCache;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AdminController extends Controller
{
    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $data['email'])->where('role', 'admin')->first();

        if (! $user || ! Hash::check($data['password'], $user->password) || $user->role !== 'admin') {
            throw ValidationException::withMessages([
                'email' => ['Admin sign-in only. Everyone else uses the mobile app.'],
            ]);
        }

        $token = $user->createToken('admin-web')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $this->adminUser($user),
        ]);
    }

    public function overview(Request $request)
    {
        $side = $request->string('side')->toString();
        $range = $request->string('range')->toString();
        $division = $side === 'law' ? 'law' : ($side === 'learning' ? 'tutor' : null);
        $since = match ($range) {
            '7' => now()->subDays(7),
            '30' => now()->subDays(30),
            default => null,
        };

        $people = User::query()->when($division, fn ($q) => $q->where('division', $division));
        $profiles = TutorProfile::query()->when($division, fn ($q) => $q->whereHas('user', fn ($u) => $u->where('division', $division)));
        $questions = Question::query()
            ->when($division, fn ($q) => $q->whereHas('student', fn ($u) => $u->where('division', $division)))
            ->when($since, fn ($q) => $q->where('created_at', '>=', $since));
        $payments = Payment::query()
            ->when($division, fn ($q) => $q->whereHas('student', fn ($u) => $u->where('division', $division)))
            ->when($since, fn ($q) => $q->where('created_at', '>=', $since));
        $lessons = Lesson::query()
            ->when($division, fn ($q) => $q->whereHas('student', fn ($u) => $u->where('division', $division)))
            ->when($since, fn ($q) => $q->where('created_at', '>=', $since));
        $subs = Subscription::query()
            ->when($division, fn ($q) => $q->whereHas('student', fn ($u) => $u->where('division', $division)));

        $pending = TutorProfile::query()
            ->with([
                'user:id,name,email,role,division',
                'user.identityDocument' => fn ($query) => $query->forAccount(),
            ])
            ->when($division, fn ($q) => $q->whereHas('user', fn ($u) => $u->where('division', $division)))
            ->where('status', 'pending')
            ->latest('id')
            ->limit(12)
            ->get();

        return response()->json([
            'filters' => ['side' => $side ?: 'all', 'range' => $range ?: 'all'],
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
            'pending_profiles' => (clone $profiles)->where('status', 'pending')->count(),
            'pending_kyc' => IdentityDocument::query()
                ->when($division, fn ($q) => $q->whereHas('user', fn ($u) => $u->where('division', $division)))
                ->where('status', 'pending')
                ->count(),
            'pending_payments' => (clone $payments)->where('status', 'pending')->count(),
            'open_questions' => (clone $questions)->where('status', 'open')->count(),
            'totals' => [
                'people' => (clone $people)->where('role', '!=', 'admin')->count(),
                'new_people' => (clone $people)->where('role', '!=', 'admin')->when($since, fn ($q) => $q->where('created_at', '>=', $since))->count(),
                'approved_teachers' => (clone $profiles)->where('status', 'approved')->count(),
                'active_subscriptions' => (clone $subs)->where('status', 'active')->count(),
                'waiting_subscriptions' => (clone $subs)->where('status', 'pending')->count(),
                'lessons' => (clone $lessons)->count(),
                'questions' => (clone $questions)->count(),
                'payments_waiting_rs' => (float) (clone $payments)->where('status', 'pending')->sum('amount'),
                'payments_received_rs' => (float) (clone $payments)->where('status', 'verified')->sum('amount'),
                'commission_waiting_rs' => (float) Commission::query()
                    ->when($division, fn ($q) => $q->whereHas('tutor', fn ($u) => $u->where('division', $division)))
                    ->where('status', 'pending')
                    ->sum('amount'),
                'mail_waiting' => DB::table('jobs')->count(),
                'mail_failed' => DB::table('failed_jobs')->count(),
            ],
            'pending' => $pending,
            'recent' => [
                'people' => User::query()
                    ->select(['id', 'name', 'email', 'role', 'division', 'created_at'])
                    ->where('role', '!=', 'admin')
                    ->when($division, fn ($q) => $q->where('division', $division))
                    ->latest('id')
                    ->limit(8)
                    ->get(),
                'payments' => Payment::query()
                    ->forAdminList()
                    ->when($division, fn ($q) => $q->whereHas('student', fn ($u) => $u->where('division', $division)))
                    ->limit(8)
                    ->get()
                    ->each(fn (Payment $payment) => $payment->makeHidden('slip_path')),
                'questions' => Question::query()
                    ->select(['id', 'student_id', 'tutor_id', 'subject_id', 'body', 'status', 'created_at'])
                    ->with(['student:id,name,division', 'tutor:id,name', 'subject:id,name'])
                    ->when($division, fn ($q) => $q->whereHas('student', fn ($u) => $u->where('division', $division)))
                    ->latest('id')
                    ->limit(8)
                    ->get(),
            ],
            'charts' => $this->charts($division, $since),
        ]);
    }

    public function profiles()
    {
        return TutorProfile::query()->forAdminDirectory()->get();
    }

    public function accounts()
    {
        return User::query()
            ->select(['id', 'name', 'email', 'phone', 'role', 'division'])
            ->whereIn('role', ['student', 'client'])
            ->latest('id')
            ->get();
    }

    public function packages()
    {
        return Package::query()
            ->select([
                'id',
                'name',
                'division',
                'description',
                'price',
                'weekly_hours',
                'includes_instant_questions',
                'includes_screen_share',
                'is_active',
            ])
            ->orderBy('division')
            ->orderBy('price')
            ->get();
    }

    public function storePackage(Request $request)
    {
        $data = $this->packagePayload($request);
        $package = Package::create($data);
        ReadCache::bump('catalog');

        return response()->json($package, 201);
    }

    public function updatePackage(Request $request, Package $package)
    {
        $package->update($this->packagePayload($request, true));
        ReadCache::bump('catalog');

        return $package->fresh();
    }

    public function refreshCache()
    {
        ReadCache::bump('catalog');
        ReadCache::bump('tutors');

        return response()->json(['status' => 'refreshed']);
    }

    public function staff()
    {
        return User::query()
            ->select(['id', 'name', 'email', 'phone', 'role', 'pages', 'created_at'])
            ->where('role', 'admin')
            ->latest('id')
            ->get()
            ->map(fn (User $user) => $this->adminUser($user));
    }

    public function storeStaff(Request $request)
    {
        $this->requireFullAdmin($request);
        $data = $request->validate([
            'name' => 'required|string|max:120',
            'email' => ['required', 'email', Rule::unique('users', 'email')->where('division', 'platform')],
            'phone' => 'nullable|string|max:30',
            'password' => 'required|string|min:6',
            'pages' => 'required|array|min:1',
            'pages.*' => 'in:'.implode(',', User::ADMIN_PAGES),
        ]);

        $pages = array_values(array_unique(array_merge($data['pages'], ['account'])));
        if (in_array('staff', $pages, true) && count($pages) === count(User::ADMIN_PAGES)) {
            $pages = null;
        }

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'] ?? null,
            'password' => $data['password'],
            'role' => 'admin',
            'division' => 'platform',
            'email_verified_at' => now(),
            'pages' => $pages,
        ]);
        AccountMailer::queueStaffWelcome($user);

        return response()->json($this->adminUser($user), 201);
    }

    public function updateStaff(Request $request, User $user)
    {
        $this->requireFullAdmin($request);
        if ($user->role !== 'admin') {
            abort(404);
        }

        $data = $request->validate([
            'name' => 'sometimes|required|string|max:120',
            'phone' => 'nullable|string|max:30',
            'password' => 'nullable|string|min:6',
            'pages' => 'sometimes|array|min:1',
            'pages.*' => 'in:'.implode(',', User::ADMIN_PAGES),
        ]);

        if (isset($data['pages'])) {
            $pages = array_values(array_unique(array_merge($data['pages'], ['account'])));
            if ($user->isFullAdmin() && $pages !== User::ADMIN_PAGES && $this->fullAdminCount() <= 1) {
                throw ValidationException::withMessages([
                    'pages' => ['Keep at least one full admin who can open every page.'],
                ]);
            }
            $data['pages'] = in_array('staff', $pages, true) && count($pages) >= count(User::ADMIN_PAGES) - 0
                ? (count($pages) === count(User::ADMIN_PAGES) ? null : $pages)
                : $pages;
            if (count($pages) === count(User::ADMIN_PAGES)) {
                $data['pages'] = null;
            } else {
                $data['pages'] = $pages;
            }
        }

        if (empty($data['password'])) {
            unset($data['password']);
        }

        $user->update($data);

        return $this->adminUser($user->fresh());
    }

    public function destroyStaff(Request $request, User $user)
    {
        $this->requireFullAdmin($request);
        if ($user->role !== 'admin') {
            abort(404);
        }
        if ((int) $user->id === (int) $request->user()->id) {
            throw ValidationException::withMessages([
                'user' => ['You cannot remove the account you are signed in with.'],
            ]);
        }
        if ($user->isFullAdmin() && $this->fullAdminCount() <= 1) {
            throw ValidationException::withMessages([
                'user' => ['Keep at least one full admin.'],
            ]);
        }
        $user->tokens()->delete();
        $user->delete();

        return response()->json(['status' => 'removed']);
    }

    public function mailQueue()
    {
        $waiting = DB::table('jobs')->orderByDesc('id')->limit(40)->get()->map(function ($job) {
            $payload = json_decode($job->payload, true) ?? [];

            return [
                'id' => $job->id,
                'name' => class_basename($payload['displayName'] ?? 'Queued mail'),
                'attempts' => $job->attempts,
                'available_at' => date('c', (int) $job->available_at),
                'created_at' => date('c', (int) $job->created_at),
            ];
        });

        $failed = DB::table('failed_jobs')->orderByDesc('id')->limit(40)->get()->map(function ($job) {
            $payload = json_decode($job->payload, true) ?? [];
            $line = strtok((string) $job->exception, "\n") ?: 'Failed';

            return [
                'id' => $job->id,
                'uuid' => $job->uuid,
                'name' => class_basename($payload['displayName'] ?? 'Queued mail'),
                'error' => mb_substr($line, 0, 240),
                'failed_at' => $job->failed_at,
            ];
        });

        return response()->json([
            'waiting' => $waiting,
            'failed' => $failed,
            'counts' => [
                'waiting' => DB::table('jobs')->count(),
                'failed' => DB::table('failed_jobs')->count(),
            ],
        ]);
    }

    public function runMailQueue()
    {
        Artisan::call('queue:work', [
            '--stop-when-empty' => true,
            '--max-time' => 25,
        ]);

        return response()->json(['status' => 'ran', 'output' => Artisan::output()]);
    }

    public function retryMail(string $uuid)
    {
        Artisan::call('queue:retry', ['id' => [$uuid]]);

        return response()->json(['status' => 'queued']);
    }

    public function retryAllMail()
    {
        Artisan::call('queue:retry', ['id' => ['all']]);

        return response()->json(['status' => 'queued']);
    }

    protected function adminUser(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
            'role' => $user->role,
            'pages' => $user->pages,
            'created_at' => $user->created_at,
        ];
    }

    protected function requireFullAdmin(Request $request): void
    {
        if (! $request->user()?->isFullAdmin()) {
            abort(403, 'Only a full admin can manage staff.');
        }
    }

    protected function fullAdminCount(): int
    {
        return User::query()->where('role', 'admin')->whereNull('pages')->count();
    }

    protected function packagePayload(Request $request, bool $partial = false): array
    {
        return $request->validate([
            'name' => ($partial ? 'sometimes|' : '').'required|string|max:120',
            'division' => ($partial ? 'sometimes|' : '').'required|in:tutor,law',
            'description' => 'nullable|string|max:2000',
            'price' => ($partial ? 'sometimes|' : '').'required|numeric|min:0|max:1000000',
            'weekly_hours' => 'sometimes|integer|min:0|max:40',
            'includes_instant_questions' => 'sometimes|boolean',
            'includes_screen_share' => 'sometimes|boolean',
            'is_active' => 'sometimes|boolean',
        ]);
    }

    protected function charts(?string $division, $since): array
    {
        $questionCounts = Question::query()
            ->whereNotNull('subject_id')
            ->when($since, fn ($q) => $q->where('created_at', '>=', $since))
            ->when($division, fn ($q) => $q->whereHas('student', fn ($u) => $u->where('division', $division)))
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
            ->when($division === 'law', fn ($q) => $q->whereRaw('0 = 1'))
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
            ->when($division === 'tutor', fn ($q) => $q->whereRaw('0 = 1'))
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
            'people' => collect([
                ['label' => 'Students', 'value' => User::where('role', 'student')->count(), 'side' => 'learning'],
                ['label' => 'Tutors', 'value' => User::where('role', 'tutor')->count(), 'side' => 'learning'],
                ['label' => 'Lecturers', 'value' => User::where('role', 'lecturer')->count(), 'side' => 'learning'],
                ['label' => 'Clients', 'value' => User::where('role', 'client')->count(), 'side' => 'law'],
                ['label' => 'Lawyers', 'value' => User::where('role', 'lawyer')->count(), 'side' => 'law'],
                ['label' => 'Legal counsel', 'value' => User::where('role', 'counsel')->count(), 'side' => 'law'],
            ])->when($division, fn ($rows) => $rows->where('side', $division === 'law' ? 'law' : 'learning')->values())->values(),
            'tracks' => $tracks,
            'law_areas' => $areas,
            'questions' => $this->statusCounts(Question::class, $division, $since),
            'lessons' => $this->statusCounts(Lesson::class, $division, $since),
            'payments' => Payment::query()
                ->when($since, fn ($q) => $q->where('created_at', '>=', $since))
                ->when($division, fn ($q) => $q->whereHas('student', fn ($u) => $u->where('division', $division)))
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

    protected function statusCounts(string $model, ?string $division, $since): array
    {
        return $model::query()
            ->when($since, fn ($q) => $q->where('created_at', '>=', $since))
            ->when($division, fn ($q) => $q->whereHas('student', fn ($u) => $u->where('division', $division)))
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
