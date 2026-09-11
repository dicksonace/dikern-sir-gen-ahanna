<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class TutorProfile extends Model
{
    protected $fillable = [
        'user_id',
        'bio',
        'qualifications',
        'experience',
        'satisfaction_points',
        'status',
        'available_slots',
        'commission_rate',
    ];

    protected function casts(): array
    {
        return [
            'available_slots' => 'array',
            'commission_rate' => 'decimal:2',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function subjects(): BelongsToMany
    {
        return $this->belongsToMany(Subject::class, 'subject_tutor');
    }
}
