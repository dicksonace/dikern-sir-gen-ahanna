<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Payment extends Model
{
    protected $hidden = [
        'slip_path',
    ];

    protected $fillable = [
        'subscription_id',
        'student_id',
        'amount',
        'method',
        'slip_path',
        'status',
        'verified_by',
        'verified_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'verified_at' => 'datetime',
        ];
    }

    public function scopeForAdminReview(Builder $query): void
    {
        $query->select([
            'payments.id',
            'payments.subscription_id',
            'payments.student_id',
            'payments.amount',
            'payments.slip_path',
            'payments.status',
            'payments.created_at',
        ])->with([
            'student:id,name,email',
            'subscription:id,package_id,tutor_id,student_id,status',
            'subscription.package:id,name',
            'subscription.tutor:id,name',
        ])->where('payments.status', 'pending')->latest('payments.id');
    }

    public function subscription(): BelongsTo
    {
        return $this->belongsTo(Subscription::class);
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(User::class, 'student_id');
    }
}
