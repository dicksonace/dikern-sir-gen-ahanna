<?php

use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\PlatformController;
use App\Http\Controllers\Api\TrackController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => response()->json([
    'app' => 'සර් ගෙන් අහන්න',
    'status' => 'ok',
    'mode' => 'prototype',
]));

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
Route::post('/reset-password', [AuthController::class, 'resetPassword']);

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

    Route::post('/subscribe', [PlatformController::class, 'subscribe']);
    Route::get('/my-subscriptions', [PlatformController::class, 'mySubscriptions']);
    Route::get('/lessons', [PlatformController::class, 'lessons']);
    Route::post('/lessons/{id}/start', [PlatformController::class, 'startLesson']);

    Route::get('/questions', [PlatformController::class, 'questions']);
    Route::post('/questions', [PlatformController::class, 'askQuestion']);
    Route::post('/questions/{id}/reply', [PlatformController::class, 'replyQuestion']);

    Route::post('/points', [PlatformController::class, 'givePoint']);
    Route::get('/tutor/earnings', [PlatformController::class, 'tutorEarnings']);

    Route::middleware('admin')->prefix('admin')->group(function () {
        Route::get('/overview', [AdminController::class, 'overview']);
        Route::get('/tracks', [TrackController::class, 'index']);
        Route::put('/tracks/{track}', [TrackController::class, 'update']);
        Route::post('/tracks/{track}/subjects', [TrackController::class, 'storeSubject']);
        Route::put('/subjects/{subject}', [TrackController::class, 'updateSubject']);
        Route::get('/stats', [PlatformController::class, 'adminStats']);
        Route::get('/pending-tutors', [PlatformController::class, 'pendingTutors']);
        Route::post('/tutors/{id}/approve', [PlatformController::class, 'approveTutor']);
        Route::get('/pending-payments', [PlatformController::class, 'pendingPayments']);
        Route::post('/payments/{id}/verify', [PlatformController::class, 'verifyPayment']);
    });
});
