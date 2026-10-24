<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
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

    public function scopeForAdminDirectory(Builder $query): void
    {
        $query->select([
            'tutor_profiles.id',
            'tutor_profiles.user_id',
            'tutor_profiles.bio',
            'tutor_profiles.qualifications',
            'tutor_profiles.experience',
            'tutor_profiles.satisfaction_points',
            'tutor_profiles.status',
            'tutor_profiles.updated_at',
        ])->with([
            'user:id,name,email,phone,role,division',
            'user.identityDocument' => fn ($query) => $query->forAccount(),
            'subjects:id,name,slug',
        ])->latest('tutor_profiles.updated_at');
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
