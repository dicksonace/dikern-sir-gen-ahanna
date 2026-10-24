<?php

namespace App\Support;

use Closure;
use Illuminate\Support\Facades\Cache;

class ReadCache
{
    public static function remember(string $group, string $key, int $seconds, Closure $callback): mixed
    {
        $version = (int) Cache::get(self::versionKey($group), 1);

        return Cache::remember("read.$group.$version.$key", $seconds, $callback);
    }

    public static function bump(string $group): void
    {
        $key = self::versionKey($group);
        if (! Cache::has($key)) {
            Cache::forever($key, 2);

            return;
        }

        Cache::increment($key);
    }

    protected static function versionKey(string $group): string
    {
        return "read.$group";
    }
}
