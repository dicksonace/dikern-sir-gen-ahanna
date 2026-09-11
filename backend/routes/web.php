<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'app' => 'සර් ගෙන් අහන්න',
        'status' => 'ok',
        'api' => url('/api/health'),
    ]);
});
