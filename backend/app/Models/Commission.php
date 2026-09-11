<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Commission extends Model
{
    protected $fillable = [
        'tutor_id',
        'subscription_id',
        'payment_id',
        'package_amount',
        'rate',
        'amount',
        'month',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'package_amount' => 'decimal:2',
            'rate' => 'decimal:2',
            'amount' => 'decimal:2',
        ];
    }

    public function tutor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'tutor_id');
    }
}
