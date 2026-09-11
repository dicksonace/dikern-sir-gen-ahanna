<?php

namespace Database\Seeders;

use App\Models\Lesson;
use App\Models\Package;
use App\Models\Question;
use App\Models\QuestionReply;
use App\Models\Subject;
use App\Models\Subscription;
use App\Models\TutorProfile;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $admin = User::create([
            'name' => 'Platform Admin',
            'email' => 'admin@sirgen.lk',
            'password' => Hash::make('password'),
            'role' => 'admin',
            'phone' => '0112000000',
        ]);

        $subjects = collect([
            ['name' => 'Mathematics', 'slug' => 'mathematics', 'icon' => 'calculate', 'color' => '#0D7377'],
            ['name' => 'Science', 'slug' => 'science', 'icon' => 'science', 'color' => '#14919B'],
            ['name' => 'English', 'slug' => 'english', 'icon' => 'menu_book', 'color' => '#2A9D8F'],
            ['name' => 'ICT', 'slug' => 'ict', 'icon' => 'computer', 'color' => '#1B4965'],
            ['name' => 'Other', 'slug' => 'other', 'icon' => 'school', 'color' => '#5C6B73'],
        ])->map(fn ($s) => Subject::create($s));

        $packages = [
            Package::create([
                'name' => 'Standard Monthly',
                'description' => '2 hours live teaching per week + instant question support + screen sharing',
                'price' => 8500,
                'weekly_hours' => 2,
                'includes_instant_questions' => true,
                'includes_screen_share' => true,
            ]),
            Package::create([
                'name' => 'Focused Weekly',
                'description' => '2 x 1-hour sessions per week + instant questions',
                'price' => 9500,
                'weekly_hours' => 2,
                'includes_instant_questions' => true,
                'includes_screen_share' => true,
            ]),
            Package::create([
                'name' => 'Intensive',
                'description' => '3 hours live teaching per week + priority question replies',
                'price' => 12000,
                'weekly_hours' => 3,
                'includes_instant_questions' => true,
                'includes_screen_share' => true,
            ]),
        ];

        $tutors = [
            [
                'name' => 'Nimal Perera',
                'email' => 'nimal@sirgen.lk',
                'bio' => 'O/L & A/L Mathematics tutor with a calm, step-by-step teaching style.',
                'qualifications' => 'BSc Mathematics – University of Colombo',
                'experience' => '8 years',
                'points' => 52,
                'subjects' => ['mathematics'],
                'slots' => ['Sat 10:00', 'Sun 16:00'],
            ],
            [
                'name' => 'Sanduni Fernando',
                'email' => 'sanduni@sirgen.lk',
                'bio' => 'Science tutor focused on exam past papers and concept clarity.',
                'qualifications' => 'BSc Biological Science',
                'experience' => '5 years',
                'points' => 38,
                'subjects' => ['science'],
                'slots' => ['Fri 18:00', 'Sun 09:00'],
            ],
            [
                'name' => 'Kasun Jayawardena',
                'email' => 'kasun@sirgen.lk',
                'bio' => 'ICT & English support for school students, including practical demos.',
                'qualifications' => 'BSc Computer Science',
                'experience' => '6 years',
                'points' => 44,
                'subjects' => ['ict', 'english'],
                'slots' => ['Wed 17:00', 'Sat 14:00'],
            ],
        ];

        $tutorUsers = [];
        foreach ($tutors as $t) {
            $user = User::create([
                'name' => $t['name'],
                'email' => $t['email'],
                'password' => Hash::make('password'),
                'role' => 'tutor',
                'phone' => '07'.random_int(10000000, 99999999),
            ]);

            $profile = TutorProfile::create([
                'user_id' => $user->id,
                'bio' => $t['bio'],
                'qualifications' => $t['qualifications'],
                'experience' => $t['experience'],
                'satisfaction_points' => $t['points'],
                'status' => 'approved',
                'available_slots' => $t['slots'],
                'commission_rate' => 60,
            ]);

            $ids = $subjects->whereIn('slug', $t['subjects'])->pluck('id');
            $profile->subjects()->sync($ids);
            $tutorUsers[] = $user;
        }

        // Pending tutor for admin demo
        $pendingTutor = User::create([
            'name' => 'Tharindu Silva',
            'email' => 'tharindu@sirgen.lk',
            'password' => Hash::make('password'),
            'role' => 'tutor',
        ]);
        $pendingProfile = TutorProfile::create([
            'user_id' => $pendingTutor->id,
            'bio' => 'Awaiting admin approval – English & Other subjects.',
            'qualifications' => 'BA English',
            'experience' => '3 years',
            'status' => 'pending',
            'available_slots' => ['Thu 19:00'],
        ]);
        $pendingProfile->subjects()->sync(
            $subjects->whereIn('slug', ['english', 'other'])->pluck('id')
        );

        $student = User::create([
            'name' => 'Amaya Wickramasinghe',
            'email' => 'student@sirgen.lk',
            'password' => Hash::make('password'),
            'role' => 'student',
            'phone' => '0771234567',
        ]);

        $subscription = Subscription::create([
            'student_id' => $student->id,
            'tutor_id' => $tutorUsers[0]->id,
            'package_id' => $packages[0]->id,
            'status' => 'active',
            'starts_at' => now()->subDays(5)->toDateString(),
            'ends_at' => now()->addDays(25)->toDateString(),
        ]);

        Lesson::create([
            'subscription_id' => $subscription->id,
            'student_id' => $student->id,
            'tutor_id' => $tutorUsers[0]->id,
            'title' => 'Algebra revision – weekly live class',
            'scheduled_at' => now()->next('Saturday')->setTime(10, 0),
            'duration_minutes' => 120,
            'status' => 'scheduled',
            'meeting_room' => 'room-demo-1',
        ]);

        Lesson::create([
            'subscription_id' => $subscription->id,
            'student_id' => $student->id,
            'tutor_id' => $tutorUsers[0]->id,
            'title' => 'Past paper walkthrough',
            'scheduled_at' => now()->subDays(7)->setTime(10, 0),
            'duration_minutes' => 120,
            'tracked_minutes' => 115,
            'status' => 'completed',
            'meeting_room' => 'room-demo-0',
        ]);

        $q = Question::create([
            'student_id' => $student->id,
            'tutor_id' => $tutorUsers[0]->id,
            'subject_id' => $subjects->firstWhere('slug', 'mathematics')->id,
            'body' => 'Sir, I am stuck on quadratic equations – how do I complete the square for x² + 6x + 5 = 0?',
            'status' => 'answered',
        ]);

        QuestionReply::create([
            'question_id' => $q->id,
            'tutor_id' => $tutorUsers[0]->id,
            'type' => 'text',
            'content' => 'Move constant: x² + 6x = -5. Add (3)² to both sides: x² + 6x + 9 = 4. Then (x+3)² = 4 → x = -1 or x = -5.',
        ]);

        Question::create([
            'student_id' => $student->id,
            'tutor_id' => $tutorUsers[0]->id,
            'subject_id' => $subjects->firstWhere('slug', 'mathematics')->id,
            'body' => 'Can you check my working for this simultaneous equations question? (photo attached in prototype)',
            'attachment_path' => 'prototype-homework.jpg',
            'status' => 'open',
        ]);

        unset($admin); // silence unused in prototype seed
    }
}
