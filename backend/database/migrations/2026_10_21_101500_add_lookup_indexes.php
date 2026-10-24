<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->index('division', 'users_division_idx');
        });

        Schema::table('questions', function (Blueprint $table) {
            $table->index(['student_id', 'status'], 'questions_student_status_idx');
            $table->index(['tutor_id', 'status'], 'questions_tutor_status_idx');
            $table->index('status', 'questions_status_idx');
        });

        Schema::table('subscriptions', function (Blueprint $table) {
            $table->index(['student_id', 'tutor_id', 'status'], 'subscriptions_student_tutor_status_idx');
        });

        Schema::table('lessons', function (Blueprint $table) {
            $table->index(['student_id', 'scheduled_at'], 'lessons_student_scheduled_idx');
            $table->index(['tutor_id', 'scheduled_at'], 'lessons_tutor_scheduled_idx');
        });

        Schema::table('tutor_profiles', function (Blueprint $table) {
            $table->index(['status', 'satisfaction_points'], 'tutor_profiles_status_points_idx');
        });

        Schema::table('subjects', function (Blueprint $table) {
            $table->index('division', 'subjects_division_idx');
        });

        Schema::table('packages', function (Blueprint $table) {
            $table->index(['division', 'is_active'], 'packages_division_active_idx');
        });

        Schema::table('tracks', function (Blueprint $table) {
            $table->index(['division', 'is_active'], 'tracks_division_active_idx');
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->index('status', 'payments_status_idx');
        });

        Schema::table('identity_documents', function (Blueprint $table) {
            $table->index('status', 'identity_documents_status_idx');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex('users_division_idx');
        });
        Schema::table('questions', function (Blueprint $table) {
            $table->dropIndex('questions_student_status_idx');
            $table->dropIndex('questions_tutor_status_idx');
            $table->dropIndex('questions_status_idx');
        });
        Schema::table('subscriptions', function (Blueprint $table) {
            $table->dropIndex('subscriptions_student_tutor_status_idx');
        });
        Schema::table('lessons', function (Blueprint $table) {
            $table->dropIndex('lessons_student_scheduled_idx');
            $table->dropIndex('lessons_tutor_scheduled_idx');
        });
        Schema::table('tutor_profiles', function (Blueprint $table) {
            $table->dropIndex('tutor_profiles_status_points_idx');
        });
        Schema::table('subjects', function (Blueprint $table) {
            $table->dropIndex('subjects_division_idx');
        });
        Schema::table('packages', function (Blueprint $table) {
            $table->dropIndex('packages_division_active_idx');
        });
        Schema::table('tracks', function (Blueprint $table) {
            $table->dropIndex('tracks_division_active_idx');
        });
        Schema::table('payments', function (Blueprint $table) {
            $table->dropIndex('payments_status_idx');
        });
        Schema::table('identity_documents', function (Blueprint $table) {
            $table->dropIndex('identity_documents_status_idx');
        });
    }
};
