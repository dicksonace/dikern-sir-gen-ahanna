<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('role')->default('student')->after('email'); // student | tutor | admin
            $table->string('phone')->nullable()->after('role');
            $table->string('avatar_url')->nullable()->after('phone');
        });

        Schema::create('subjects', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug')->unique();
            $table->string('icon')->nullable();
            $table->string('color')->nullable();
            $table->timestamps();
        });

        Schema::create('tutor_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->text('bio')->nullable();
            $table->string('qualifications')->nullable();
            $table->string('experience')->nullable();
            $table->unsignedInteger('satisfaction_points')->default(0);
            $table->string('status')->default('pending'); // pending | approved | rejected
            $table->json('available_slots')->nullable();
            $table->decimal('commission_rate', 5, 2)->default(60.00);
            $table->timestamps();
        });

        Schema::create('subject_tutor', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tutor_profile_id')->constrained()->cascadeOnDelete();
            $table->foreignId('subject_id')->constrained()->cascadeOnDelete();
            $table->unique(['tutor_profile_id', 'subject_id']);
        });

        Schema::create('packages', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('description')->nullable();
            $table->decimal('price', 10, 2);
            $table->unsignedInteger('weekly_hours')->default(2);
            $table->boolean('includes_instant_questions')->default(true);
            $table->boolean('includes_screen_share')->default(true);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::create('subscriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('student_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('tutor_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('package_id')->constrained()->cascadeOnDelete();
            $table->string('status')->default('pending'); // pending | active | expired | cancelled
            $table->date('starts_at')->nullable();
            $table->date('ends_at')->nullable();
            $table->timestamps();
        });

        Schema::create('payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('subscription_id')->constrained()->cascadeOnDelete();
            $table->foreignId('student_id')->constrained('users')->cascadeOnDelete();
            $table->decimal('amount', 10, 2);
            $table->string('method')->default('bank_transfer');
            $table->string('slip_path')->nullable();
            $table->string('status')->default('pending'); // pending | verified | rejected
            $table->foreignId('verified_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('verified_at')->nullable();
            $table->timestamps();
        });

        Schema::create('lessons', function (Blueprint $table) {
            $table->id();
            $table->foreignId('subscription_id')->constrained()->cascadeOnDelete();
            $table->foreignId('student_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('tutor_id')->constrained('users')->cascadeOnDelete();
            $table->string('title');
            $table->dateTime('scheduled_at');
            $table->unsignedInteger('duration_minutes')->default(120);
            $table->unsignedInteger('tracked_minutes')->default(0);
            $table->string('status')->default('scheduled'); // scheduled | live | completed | cancelled
            $table->string('meeting_room')->nullable();
            $table->timestamps();
        });

        Schema::create('questions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('student_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('tutor_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('subject_id')->nullable()->constrained()->nullOnDelete();
            $table->text('body');
            $table->string('attachment_path')->nullable();
            $table->string('status')->default('open'); // open | answered | closed
            $table->timestamps();
        });

        Schema::create('question_replies', function (Blueprint $table) {
            $table->id();
            $table->foreignId('question_id')->constrained()->cascadeOnDelete();
            $table->foreignId('tutor_id')->constrained('users')->cascadeOnDelete();
            $table->string('type')->default('text'); // text | image | document | video
            $table->text('content')->nullable();
            $table->string('attachment_path')->nullable();
            $table->timestamps();
        });

        Schema::create('satisfaction_points', function (Blueprint $table) {
            $table->id();
            $table->foreignId('student_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('tutor_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('lesson_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('question_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamps();
            $table->unique(['student_id', 'tutor_id', 'lesson_id']);
        });

        Schema::create('commissions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('tutor_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('subscription_id')->constrained()->cascadeOnDelete();
            $table->foreignId('payment_id')->constrained()->cascadeOnDelete();
            $table->decimal('package_amount', 10, 2);
            $table->decimal('rate', 5, 2);
            $table->decimal('amount', 10, 2);
            $table->string('month'); // YYYY-MM
            $table->string('status')->default('pending'); // pending | paid
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('commissions');
        Schema::dropIfExists('satisfaction_points');
        Schema::dropIfExists('question_replies');
        Schema::dropIfExists('questions');
        Schema::dropIfExists('lessons');
        Schema::dropIfExists('payments');
        Schema::dropIfExists('subscriptions');
        Schema::dropIfExists('packages');
        Schema::dropIfExists('subject_tutor');
        Schema::dropIfExists('tutor_profiles');
        Schema::dropIfExists('subjects');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['role', 'phone', 'avatar_url']);
        });
    }
};
