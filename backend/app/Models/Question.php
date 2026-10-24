<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Question extends Model
{
    protected $fillable = [
        'student_id',
        'tutor_id',
        'subject_id',
        'body',
        'attachment_path',
        'status',
    ];

    protected $appends = [
        'attachment_url',
        'attachment_kind',
    ];

    public function getAttachmentUrlAttribute(): ?string
    {
        if (! is_string($this->attachment_path) || ! str_contains($this->attachment_path, '/')) {
            return null;
        }

        return url('/api/questions/'.$this->id.'/file');
    }

    public function getAttachmentKindAttribute(): ?string
    {
        return $this->kindFromPath($this->attachment_path);
    }

    protected function kindFromPath(?string $path): ?string
    {
        $path = strtolower((string) $path);
        if ($path === '') {
            return null;
        }
        if (str_ends_with($path, '.mp4') || str_ends_with($path, '.mov')) {
            return 'video';
        }
        if (preg_match('/\.(jpg|jpeg|png|webp)$/', $path)) {
            return 'image';
        }

        return 'file';
    }

    public function student(): BelongsTo
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    public function tutor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'tutor_id');
    }

    public function subject(): BelongsTo
    {
        return $this->belongsTo(Subject::class);
    }

    public function replies(): HasMany
    {
        return $this->hasMany(QuestionReply::class)->orderBy('id');
    }

    public function latestReply(): HasOne
    {
        return $this->hasOne(QuestionReply::class)->latestOfMany();
    }

    public function scopeListColumns(Builder $query): Builder
    {
        return $query->select([
            'id',
            'student_id',
            'tutor_id',
            'subject_id',
            'body',
            'attachment_path',
            'status',
            'created_at',
        ]);
    }

    public function scopeVisibleTo(Builder $query, User $user): Builder
    {
        if (in_array($user->role, ['student', 'client'], true)) {
            return $query->where('student_id', $user->id);
        }

        if (in_array($user->role, User::PROVIDER_ROLES, true)) {
            return $query->where('tutor_id', $user->id);
        }

        return $query->whereRaw('1 = 0');
    }

    public function forInboxList(): static
    {
        $this->setRelation('replies', $this->latestReply ? collect([$this->latestReply]) : collect());
        $this->unsetRelation('latestReply');

        return $this;
    }
}
