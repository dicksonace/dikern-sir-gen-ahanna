<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\PlatformController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => response()->json([
    'app' => 'සර් ගෙන් අහන්න',
    'status' => 'ok',
    'mode' => 'prototype',
]));

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::get('/subjects', [PlatformController::class, 'subjects']);
Route::get('/packages', [PlatformController::class, 'packages']);
Route::get('/tutors', [PlatformController::class, 'tutors']);
Route::get('/tutors/{id}', [PlatformController::class, 'tutorShow']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
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

    Route::prefix('admin')->group(function () {
        Route::get('/stats', [PlatformController::class, 'adminStats']);
        Route::get('/pending-tutors', [PlatformController::class, 'pendingTutors']);
        Route::post('/tutors/{id}/approve', [PlatformController::class, 'approveTutor']);
        Route::get('/pending-payments', [PlatformController::class, 'pendingPayments']);
        Route::post('/payments/{id}/verify', [PlatformController::class, 'verifyPayment']);
    });
});
