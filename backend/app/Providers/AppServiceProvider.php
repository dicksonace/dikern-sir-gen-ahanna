<?php

namespace App\Providers;

use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        if ($this->app->environment('production')) {
            URL::forceScheme('https');
            if ($root = config('app.url')) {
                URL::forceRootUrl($root);
            }
        }

        if ($this->app->runningInConsole()) {
            return;
        }

        $this->app->terminating(function () {
            if (config('queue.default') !== 'database' || ! Schema::hasTable('jobs')) {
                return;
            }
            if (DB::table('jobs')->count() === 0) {
                return;
            }

            Artisan::call('queue:work', [
                '--stop-when-empty' => true,
                '--max-jobs' => 8,
                '--tries' => 3,
                '--timeout' => 30,
            ]);
        });
    }
}
