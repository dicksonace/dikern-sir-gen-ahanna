<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commission;
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
use Illuminate\Http\Request;

class PlatformController extends Controller
{
    public function subjects(Request $request)
    {
        return Subject::query()
            ->when($this->division($request), fn ($q, $division) => $q->where('division', $division))
            ->when($request->filled('track'), function ($query) use ($request) {
                $slug = $request->string('track')->toString();
                $query->whereHas('track', fn ($q) => $q->where('slug', $slug));
            })
            ->orderBy('name')
            ->get();
    }

    public function tracks(Request $request)
    {
        return Track::query()
            ->with('subjects')
            ->where('is_active', true)
            ->when($this->division($request), fn ($q, $division) => $q->where('division', $division))
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();
    }

    public function packages(Request $request)
    {
        return Package::query()
            ->where('is_active', true)
            ->when($this->division($request), fn ($q, $division) => $q->where('division', $division))
            ->orderBy('price')
            ->get();
    }

    public function tutors(Request $request)
    {
        $query = TutorProfile::with(['user', 'subjects'])
            ->where('status', 'approved');

        if ($division = $this->division($request)) {
            $query->whereHas('user', fn ($q) => $q->where('division', $division));
        }

        if ($request->filled('subject')) {
            $slug = $request->string('subject');
            $query->whereHas('subjects', fn ($q) => $q->where('slug', $slug));
        }

        return $query->orderByDesc('satisfaction_points')->get();
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
            'slip_note' => 'nullable|string|max:255',
        ]);

        $package = Package::findOrFail($data['package_id']);

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
            'slip_path' => $data['slip_note'] ?? 'prototype-slip.jpg',
            'status' => 'pending',
        ]);

        return response()->json([
            'subscription' => $subscription->load(['package', 'tutor', 'payment']),
            'payment' => $payment,
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
        $query = Lesson::with(['student', 'tutor']);

        if ($user->role === 'student') {
            $query->where('student_id', $user->id);
        } elseif ($user->role === 'tutor') {
            $query->where('tutor_id', $user->id);
        }

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
        $user = $request->user();
        $query = Question::with(['student', 'tutor', 'subject', 'replies']);

        if ($user->role === 'student') {
            $query->where('student_id', $user->id);
        } elseif ($user->role === 'tutor') {
            $query->where('tutor_id', $user->id);
        }

        return $query->latest()->get();
    }

    public function askQuestion(Request $request)
    {
        $data = $request->validate([
            'tutor_id' => 'required|exists:users,id',
            'subject_id' => 'nullable|exists:subjects,id',
            'body' => 'required|string|max:2000',
            'attachment_path' => 'nullable|string',
        ]);

        $question = Question::create([
            'student_id' => $request->user()->id,
            'tutor_id' => $data['tutor_id'],
            'subject_id' => $data['subject_id'] ?? null,
            'body' => $data['body'],
            'attachment_path' => $data['attachment_path'] ?? null,
            'status' => 'open',
        ]);

        return response()->json($question->load(['subject', 'tutor']), 201);
    }

    public function replyQuestion(Request $request, int $id)
    {
        $question = Question::findOrFail($id);

        $data = $request->validate([
            'type' => 'required|in:text,image,document,video',
            'content' => 'nullable|string',
            'attachment_path' => 'nullable|string',
        ]);

        $reply = QuestionReply::create([
            'question_id' => $question->id,
            'tutor_id' => $request->user()->id,
            'type' => $data['type'],
            'content' => $data['content'] ?? null,
            'attachment_path' => $data['attachment_path'] ?? null,
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
        $profile = TutorProfile::findOrFail($id);
        $profile->update(['status' => 'approved']);

        return response()->json($profile->load(['user', 'subjects']));
    }

    public function pendingPayments()
    {
        return Payment::with(['student', 'subscription.package', 'subscription.tutor'])
            ->where('status', 'pending')
            ->latest()
            ->get();
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

    protected function division(Request $request): ?string
    {
        $division = $request->string('division')->toString();
        if (! in_array($division, ['tutor', 'law'], true)) {
            $division = $request->user()?->division;
        }

        return in_array($division, ['tutor', 'law'], true) ? $division : null;
    }
}
