<?php

use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\IdentityController;
use App\Http\Controllers\Api\PlatformController;
use App\Http\Controllers\Api\TrackController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => response()->json([
    'app' => 'සර් ගෙන් අහන්න',
    'status' => 'ok',
    'mode' => 'prototype',
]));

Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:8,1');
Route::post('/login', [AuthController::class, 'login']);
Route::post('/verify-email', [AuthController::class, 'verifyEmail'])->middleware('throttle:8,1');
Route::post('/resend-verification', [AuthController::class, 'resendVerification'])->middleware('throttle:3,1');
Route::post('/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:6,1');
Route::post('/reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:6,1');

Route::get('/subjects', [PlatformController::class, 'subjects']);
Route::get('/tracks', [PlatformController::class, 'tracks']);
Route::get('/packages', [PlatformController::class, 'packages']);
Route::get('/tutors', [PlatformController::class, 'tutors']);
Route::get('/tutors/{id}', [PlatformController::class, 'tutorShow']);

Route::post('/admin/login', [AdminController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::put('/profile', [AuthController::class, 'updateProfile']);
    Route::post('/change-password', [AuthController::class, 'changePassword']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/kyc', [IdentityController::class, 'show']);
    Route::post('/kyc', [IdentityController::class, 'store']);

    Route::post('/subscribe', [PlatformController::class, 'subscribe']);
    Route::get('/my-subscriptions', [PlatformController::class, 'mySubscriptions']);
    Route::get('/lessons', [PlatformController::class, 'lessons']);
    Route::post('/lessons/{id}/start', [PlatformController::class, 'startLesson']);

    Route::get('/questions', [PlatformController::class, 'questions']);
    Route::post('/questions', [PlatformController::class, 'askQuestion']);
    Route::get('/questions/{id}', [PlatformController::class, 'showQuestion']);
    Route::post('/questions/{id}/close', [PlatformController::class, 'closeQuestion']);
    Route::get('/questions/{id}/file', [PlatformController::class, 'questionFile']);
    Route::get('/questions/{id}/replies/{reply}/file', [PlatformController::class, 'replyFile']);
    Route::post('/questions/{id}/reply', [PlatformController::class, 'replyQuestion']);

    Route::post('/points', [PlatformController::class, 'givePoint']);
    Route::get('/tutor/earnings', [PlatformController::class, 'tutorEarnings']);

    Route::middleware('admin')->prefix('admin')->group(function () {
        Route::get('/overview', [AdminController::class, 'overview']);
        Route::get('/profiles', [AdminController::class, 'profiles']);
        Route::get('/accounts', [AdminController::class, 'accounts']);
        Route::get('/questions', [PlatformController::class, 'adminQuestions']);
        Route::post('/questions/{id}/close', [PlatformController::class, 'adminCloseQuestion']);
        Route::get('/questions/{id}/file', [PlatformController::class, 'adminQuestionFile']);
        Route::get('/questions/{id}/replies/{reply}/file', [PlatformController::class, 'adminReplyFile']);
        Route::get('/lessons', [PlatformController::class, 'adminLessons']);
        Route::get('/tracks', [TrackController::class, 'index']);
        Route::put('/tracks/{track}', [TrackController::class, 'update']);
        Route::post('/tracks/{track}/subjects', [TrackController::class, 'storeSubject']);
        Route::put('/subjects/{subject}', [TrackController::class, 'updateSubject']);
        Route::get('/stats', [PlatformController::class, 'adminStats']);
        Route::get('/kyc', [IdentityController::class, 'pending']);
        Route::get('/kyc/{id}/file', [IdentityController::class, 'file']);
        Route::post('/kyc/{id}/approve', [IdentityController::class, 'approve']);
        Route::post('/kyc/{id}/reject', [IdentityController::class, 'reject']);
        Route::get('/pending-tutors', [PlatformController::class, 'pendingTutors']);
        Route::post('/tutors/{id}/approve', [PlatformController::class, 'approveTutor']);
        Route::get('/pending-payments', [PlatformController::class, 'pendingPayments']);
        Route::get('/payments/{id}/file', [PlatformController::class, 'paymentFile']);
        Route::post('/payments/{id}/verify', [PlatformController::class, 'verifyPayment']);
    });
});
