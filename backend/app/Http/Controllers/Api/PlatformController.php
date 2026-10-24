<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commission;
use App\Models\IdentityDocument;
use App\Models\Lesson;
use App\Models\Package;
use App\Models\Payment;
use App\Models\Question;
use App\Models\QuestionReply;
use App\Models\SatisfactionPoint;
use App\Models\Subject;
use App\Models\Subscription;
use App\Models\Track;
use App\Models\TutorProfile;
use App\Models\User;
use App\Support\AccountMailer;
use App\Support\ReadCache;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class PlatformController extends Controller
{
    public function subjects(Request $request)
    {
        $division = $this->division($request) ?? 'all';
        $track = $request->string('track')->toString() ?: 'all';

        return ReadCache::remember('catalog', "subjects.$division.$track", 600, function () use ($request) {
            return Subject::query()
                ->select(['id', 'name', 'slug', 'icon', 'color', 'division', 'track_id'])
                ->when($this->division($request), fn ($q, $division) => $q->where('division', $division))
                ->when($request->filled('track'), function ($query) use ($request) {
                    $slug = $request->string('track')->toString();
                    $query->whereHas('track', fn ($q) => $q->where('slug', $slug));
                })
                ->orderBy('name')
                ->get();
        });
    }

    public function tracks(Request $request)
    {
        $division = $this->division($request) ?? 'all';

        return ReadCache::remember('catalog', "tracks.$division", 600, function () use ($request) {
            return Track::query()
                ->with('subjects:id,track_id,name,slug,icon,color')
                ->where('is_active', true)
                ->when($this->division($request), fn ($q, $division) => $q->where('division', $division))
                ->orderBy('sort_order')
                ->orderBy('name')
                ->get();
        });
    }

    public function packages(Request $request)
    {
        $division = $this->division($request) ?? 'all';

        return ReadCache::remember('catalog', "packages.$division", 600, function () use ($request) {
            return Package::query()
                ->select(['id', 'name', 'description', 'price', 'weekly_hours', 'division', 'is_active'])
                ->where('is_active', true)
                ->when($this->division($request), fn ($q, $division) => $q->where('division', $division))
                ->orderBy('price')
                ->get();
        });
    }

    public function tutors(Request $request)
    {
        $division = $this->division($request) ?? 'all';
        $subject = $request->string('subject')->toString() ?: 'all';

        return ReadCache::remember('tutors', "$division.$subject", 60, function () use ($request, $division) {
            $query = TutorProfile::query()
                ->select(['id', 'user_id', 'bio', 'qualifications', 'experience', 'satisfaction_points', 'status', 'available_slots', 'commission_rate'])
                ->with([
                    'user:id,name,role,division',
                    'subjects:id,name,slug,icon,color',
                ])
                ->where('status', 'approved');

            if ($division !== 'all') {
                $query->whereHas('user', fn ($q) => $q->where('division', $division));
            }

            if ($request->filled('subject')) {
                $slug = $request->string('subject');
                $query->whereHas('subjects', fn ($q) => $q->where('slug', $slug));
            }

            return $query->orderByDesc('satisfaction_points')->get();
        });
    }

    public function tutorShow(int $id)
    {
        return TutorProfile::with(['user', 'subjects'])
            ->where('status', 'approved')
            ->findOrFail($id);
    }

    public function subscribe(Request $request)
    {
        $data = $request->validate([
            'tutor_id' => 'required|exists:users,id',
            'package_id' => 'required|exists:packages,id',
            'slip' => 'nullable|file|mimes:jpg,jpeg,png,webp,pdf|max:5120',
            'slip_note' => 'nullable|string|max:255',
        ]);

        $package = Package::findOrFail($data['package_id']);
        $slipPath = $data['slip_note'] ?? null;

        if ($request->hasFile('slip')) {
            $file = $request->file('slip');
            $safeName = preg_replace('/[^A-Za-z0-9._-]/', '_', $file->getClientOriginalName()) ?: 'slip';
            $slipPath = $file->storeAs('slips/'.$request->user()->id, now()->format('YmdHis').'-'.$safeName, 'local');
        }

        $subscription = Subscription::create([
            'student_id' => $request->user()->id,
            'tutor_id' => $data['tutor_id'],
            'package_id' => $package->id,
            'status' => 'pending',
        ]);

        $payment = Payment::create([
            'subscription_id' => $subscription->id,
            'student_id' => $request->user()->id,
            'amount' => $package->price,
            'method' => 'bank_transfer',
            'slip_path' => $slipPath,
            'status' => 'pending',
        ]);

        $subscription->load(['package', 'tutor', 'payment']);
        $subscription->payment?->makeHidden('slip_path');

        return response()->json([
            'subscription' => $subscription,
            'payment' => $payment->makeHidden('slip_path'),
            'message' => 'Bank transfer submitted. Admin will verify shortly.',
        ], 201);
    }

    public function mySubscriptions(Request $request)
    {
        return Subscription::with(['package', 'tutor', 'payment'])
            ->where('student_id', $request->user()->id)
            ->latest()
            ->get();
    }

    public function lessons(Request $request)
    {
        $user = $request->user();
        $query = Lesson::query()
            ->select(['id', 'student_id', 'tutor_id', 'title', 'scheduled_at', 'duration_minutes', 'tracked_minutes', 'status', 'meeting_room'])
            ->with(['student:id,name,role', 'tutor:id,name,role']);
        $this->limitToPerson($query, $user, 'student_id', 'tutor_id');

        return $query->orderBy('scheduled_at')->get();
    }

    public function startLesson(Request $request, int $id)
    {
        $lesson = Lesson::findOrFail($id);
        $lesson->update([
            'status' => 'live',
            'meeting_room' => $lesson->meeting_room ?: 'room-'.$lesson->id,
        ]);

        return response()->json([
            'lesson' => $lesson,
            'prototype_note' => 'Live video + screen share will be integrated in production (WebRTC).',
        ]);
    }

    public function questions(Request $request)
    {
        return Question::query()
            ->listColumns()
            ->visibleTo($request->user())
            ->with([
                'student:id,name,role',
                'tutor:id,name,role',
                'subject:id,name,slug',
                'latestReply.tutor:id,name,role',
            ])
            ->latest('id')
            ->get()
            ->each
            ->forInboxList();
    }

    public function showQuestion(Request $request, int $id)
    {
        return response()->json($this->findVisibleQuestion($request, $id));
    }

    public function closeQuestion(Request $request, int $id)
    {
        $question = $this->findVisibleQuestion($request, $id);

        if ($question->status !== 'closed') {
            $question->update(['status' => 'closed']);
        }

        return response()->json($this->findVisibleQuestion($request, $id));
    }

    public function askQuestion(Request $request)
    {
        $data = $request->validate([
            'tutor_id' => 'required|exists:users,id',
            'subject_id' => 'nullable|exists:subjects,id',
            'body' => 'nullable|string|max:2000',
            'attachment' => 'nullable|file|mimes:jpg,jpeg,png,webp,mp4,mov,pdf|max:20480',
        ]);

        $body = trim((string) ($data['body'] ?? ''));
        if ($body === '' && ! $request->hasFile('attachment')) {
            throw ValidationException::withMessages([
                'body' => ['Write a question or add a photo or video.'],
            ]);
        }

        $paid = Subscription::query()
            ->where('student_id', $request->user()->id)
            ->where('tutor_id', $data['tutor_id'])
            ->where('status', 'active')
            ->where(function ($query) {
                $query->whereNull('ends_at')->orWhere('ends_at', '>=', now()->toDateString());
            })
            ->exists();

        if (! $paid) {
            throw ValidationException::withMessages([
                'tutor_id' => ['You can only ask someone you have an active paid package with.'],
            ]);
        }

        $question = Question::create([
            'student_id' => $request->user()->id,
            'tutor_id' => $data['tutor_id'],
            'subject_id' => $data['subject_id'] ?? null,
            'body' => $body !== '' ? $body : 'Attached a file.',
            'attachment_path' => $this->storeQuestionFile($request, 'questions/'.$request->user()->id),
            'status' => 'open',
        ]);

        return response()->json($question->load(['subject', 'tutor']), 201);
    }

    public function replyQuestion(Request $request, int $id)
    {
        $question = Question::findOrFail($id);

        if ((int) $question->tutor_id !== (int) $request->user()->id) {
            abort(403);
        }

        if ($question->status === 'closed') {
            throw ValidationException::withMessages([
                'status' => ['This question is closed.'],
            ]);
        }

        $data = $request->validate([
            'type' => 'required|in:text,image,document,video',
            'content' => 'nullable|string',
            'attachment' => 'nullable|file|mimes:jpg,jpeg,png,webp,mp4,mov,pdf|max:20480',
        ]);

        if ($data['type'] !== 'text' && ! $request->hasFile('attachment')) {
            throw ValidationException::withMessages([
                'attachment' => ['Choose the photo, video, or document to send.'],
            ]);
        }

        $reply = QuestionReply::create([
            'question_id' => $question->id,
            'tutor_id' => $request->user()->id,
            'type' => $data['type'],
            'content' => $data['content'] ?? null,
            'attachment_path' => $this->storeQuestionFile($request, 'replies/'.$question->id),
        ]);

        $question->update(['status' => 'answered']);

        return response()->json($reply, 201);
    }

    public function givePoint(Request $request)
    {
        $data = $request->validate([
            'tutor_id' => 'required|exists:users,id',
            'lesson_id' => 'nullable|exists:lessons,id',
            'question_id' => 'nullable|exists:questions,id',
        ]);

        $point = SatisfactionPoint::firstOrCreate([
            'student_id' => $request->user()->id,
            'tutor_id' => $data['tutor_id'],
            'lesson_id' => $data['lesson_id'] ?? null,
        ], [
            'question_id' => $data['question_id'] ?? null,
        ]);

        if ($point->wasRecentlyCreated) {
            $profile = TutorProfile::where('user_id', $data['tutor_id'])->first();
            if ($profile) {
                $profile->increment('satisfaction_points');
            }
        }

        return response()->json([
            'message' => 'Thanks! Satisfaction point given.',
            'point' => $point,
        ]);
    }

    public function tutorEarnings(Request $request)
    {
        return Commission::where('tutor_id', $request->user()->id)
            ->latest()
            ->get();
    }

    // --- Admin ---

    public function pendingTutors()
    {
        return TutorProfile::with(['user', 'subjects'])
            ->where('status', 'pending')
            ->latest()
            ->get();
    }

    public function approveTutor(int $id)
    {
        $profile = TutorProfile::with('user')->findOrFail($id);
        $hasIdentity = IdentityDocument::where('user_id', $profile->user_id)->where('status', 'approved')->exists();

        if (! $hasIdentity) {
            throw ValidationException::withMessages([
                'kyc' => ['Approve this person\'s identity document before approving the profile.'],
            ]);
        }

        $profile->update(['status' => 'approved']);
        ReadCache::bump('tutors');
        if ($profile->user) {
            AccountMailer::queueProfileApproved($profile->user);
        }

        return response()->json($profile->load(['user', 'subjects']));
    }

    public function pendingPayments()
    {
        return Payment::query()->forAdminReview()->get()->each(function (Payment $payment) {
            $stored = is_string($payment->slip_path) && Storage::disk('local')->exists($payment->slip_path);
            $payment->setAttribute('has_slip', $stored);
            $payment->makeHidden('slip_path');
        });
    }

    public function paymentFile(int $id)
    {
        $payment = Payment::query()->select(['id', 'slip_path'])->findOrFail($id);

        if (! is_string($payment->slip_path) || ! Storage::disk('local')->exists($payment->slip_path)) {
            abort(404);
        }

        $name = preg_replace('/[^A-Za-z0-9._-]/', '_', basename($payment->slip_path)) ?: 'slip';

        return Storage::disk('local')->response($payment->slip_path, $name);
    }

    public function verifyPayment(Request $request, int $id)
    {
        $payment = Payment::with('subscription.package')->findOrFail($id);
        $payment->update([
            'status' => 'verified',
            'verified_by' => $request->user()->id,
            'verified_at' => now(),
        ]);

        $sub = $payment->subscription;
        $sub->update([
            'status' => 'active',
            'starts_at' => now()->toDateString(),
            'ends_at' => now()->addMonth()->toDateString(),
        ]);

        $student = User::find($sub->student_id);
        if ($student) {
            AccountMailer::queuePaymentVerified($student, $sub->package->name ?? 'your package');
        }

        $tutor = User::with('tutorProfile')->find($sub->tutor_id);
        $rate = (float) ($tutor->tutorProfile->commission_rate ?? 60);
        $amount = round(((float) $payment->amount) * ($rate / 100), 2);

        Commission::create([
            'tutor_id' => $sub->tutor_id,
            'subscription_id' => $sub->id,
            'payment_id' => $payment->id,
            'package_amount' => $payment->amount,
            'rate' => $rate,
            'amount' => $amount,
            'month' => now()->format('Y-m'),
            'status' => 'pending',
        ]);

        // Seed a sample upcoming lesson for the prototype
        Lesson::create([
            'subscription_id' => $sub->id,
            'student_id' => $sub->student_id,
            'tutor_id' => $sub->tutor_id,
            'title' => 'Weekly live lesson',
            'scheduled_at' => now()->next('Saturday')->setTime(10, 0),
            'duration_minutes' => ($sub->package->weekly_hours ?? 2) * 60,
            'status' => 'scheduled',
            'meeting_room' => 'room-'.$sub->id,
        ]);

        return response()->json([
            'payment' => $payment->fresh(),
            'subscription' => $sub->fresh(),
        ]);
    }

    public function adminQuestions()
    {
        return Question::query()
            ->listColumns()
            ->with([
                'student:id,name,role,division',
                'tutor:id,name,role',
                'subject:id,name',
                'replies:id,question_id,tutor_id,content,attachment_path,created_at',
                'replies.tutor:id,name',
            ])
            ->latest('id')
            ->get()
            ->each(function (Question $question) {
                $this->markStoredFile($question);
                $question->replies->each(fn (QuestionReply $reply) => $this->markStoredFile($reply));
            });
    }

    public function adminCloseQuestion(int $id)
    {
        $question = Question::query()->findOrFail($id);
        if ($question->status !== 'closed') {
            $question->update(['status' => 'closed']);
        }

        return response()->json(['status' => 'closed']);
    }

    public function adminQuestionFile(int $id)
    {
        $question = Question::query()->select(['id', 'attachment_path'])->findOrFail($id);

        return $this->fileResponse($question->attachment_path);
    }

    public function adminReplyFile(int $id, int $reply)
    {
        $row = QuestionReply::query()
            ->select(['id', 'question_id', 'attachment_path'])
            ->where('question_id', $id)
            ->findOrFail($reply);

        return $this->fileResponse($row->attachment_path);
    }

    public function adminLessons()
    {
        return Lesson::query()
            ->select(['id', 'student_id', 'tutor_id', 'title', 'scheduled_at', 'duration_minutes', 'status'])
            ->with([
                'student:id,name',
                'tutor:id,name',
            ])
            ->latest('scheduled_at')
            ->get();
    }

    public function adminStats()
    {
        return response()->json([
            'students' => User::where('role', 'student')->count(),
            'tutors' => TutorProfile::where('status', 'approved')->count(),
            'pending_tutors' => TutorProfile::where('status', 'pending')->count(),
            'pending_payments' => Payment::where('status', 'pending')->count(),
            'active_subscriptions' => Subscription::where('status', 'active')->count(),
            'open_questions' => Question::where('status', 'open')->count(),
        ]);
    }

    public function questionFile(Request $request, int $id)
    {
        $question = Question::findOrFail($id);
        $this->ensureQuestionAccess($request->user(), $question);

        return $this->fileResponse($question->attachment_path);
    }

    public function replyFile(Request $request, int $id, int $reply)
    {
        $question = Question::findOrFail($id);
        $this->ensureQuestionAccess($request->user(), $question);
        $row = QuestionReply::where('question_id', $question->id)->findOrFail($reply);

        return $this->fileResponse($row->attachment_path);
    }

    protected function findVisibleQuestion(Request $request, int $id): Question
    {
        $question = Question::with([
            'student:id,name,role',
            'tutor:id,name,role',
            'subject:id,name,slug',
            'replies.tutor:id,name,role',
        ])->findOrFail($id);

        $this->ensureQuestionAccess($request->user(), $question);

        return $question;
    }

    protected function ensureQuestionAccess(User $user, Question $question): void
    {
        if ((int) $question->student_id === (int) $user->id || (int) $question->tutor_id === (int) $user->id) {
            return;
        }

        abort(403);
    }

    protected function storeQuestionFile(Request $request, string $folder): ?string
    {
        if (! $request->hasFile('attachment')) {
            return null;
        }

        $file = $request->file('attachment');
        $safe = preg_replace('/[^A-Za-z0-9._-]/', '_', $file->getClientOriginalName()) ?: 'file';

        return $file->storeAs($folder, now()->format('YmdHis').'-'.$safe, 'local');
    }

    protected function markStoredFile(Question|QuestionReply $row): void
    {
        $path = $row->attachment_path;
        $row->setAttribute('has_attachment', is_string($path) && Storage::disk('local')->exists($path));
        $row->makeHidden(['attachment_path', 'attachment_url']);
    }

    protected function fileResponse(?string $path)
    {
        if (! $path || ! Storage::disk('local')->exists($path)) {
            abort(404);
        }

        return Storage::disk('local')->response($path);
    }

    protected function limitToPerson($query, User $user, string $askerColumn, string $providerColumn): void
    {
        if (in_array($user->role, ['student', 'client'], true)) {
            $query->where($askerColumn, $user->id);

            return;
        }

        if (in_array($user->role, User::PROVIDER_ROLES, true)) {
            $query->where($providerColumn, $user->id);

            return;
        }

        $query->whereRaw('1 = 0');
    }

    protected function division(Request $request): ?string
    {
        $division = $request->string('division')->toString();
        if (! in_array($division, ['tutor', 'law'], true)) {
            $division = $request->user()?->division;
        }

        return in_array($division, ['tutor', 'law'], true) ? $division : null;
    }
}
