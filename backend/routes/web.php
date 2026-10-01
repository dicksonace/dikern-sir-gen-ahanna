<?php

use App\Http\Controllers\AdminWebController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'app' => 'සර් ගෙන් අහන්න',
        'status' => 'ok',
        'api' => url('/api/health'),
        'admin' => url('/admin/login'),
    ]);
});

Route::get('/admin/login', [AdminWebController::class, 'showLogin'])->name('admin.login');
Route::post('/admin/login', [AdminWebController::class, 'login'])->name('admin.login.submit');

Route::middleware('auth')->prefix('admin')->group(function () {
    Route::get('/', [AdminWebController::class, 'dashboard'])->name('admin.dashboard');
    Route::post('/profiles/{profile}/approve', [AdminWebController::class, 'approve'])->name('admin.approve');
    Route::post('/logout', [AdminWebController::class, 'logout'])->name('admin.logout');
});
