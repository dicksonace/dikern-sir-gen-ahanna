<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'phone',
        'avatar_url',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function tutorProfile(): HasOne
    {
        return $this->hasOne(TutorProfile::class);
    }

    public function studentSubscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class, 'student_id');
    }

    public function tutorSubscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class, 'tutor_id');
    }

    public function questionsAsked(): HasMany
    {
        return $this->hasMany(Question::class, 'student_id');
    }

    public function questionsReceived(): HasMany
    {
        return $this->hasMany(Question::class, 'tutor_id');
    }

    public function commissions(): HasMany
    {
        return $this->hasMany(Commission::class, 'tutor_id');
    }
}
