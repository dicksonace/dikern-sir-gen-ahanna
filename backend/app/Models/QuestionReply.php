<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class QuestionReply extends Model
{
    protected $fillable = [
        'question_id',
        'tutor_id',
        'type',
        'content',
        'attachment_path',
    ];

    protected $appends = [
        'attachment_url',
        'attachment_kind',
    ];

    protected function casts(): array
    {
        return [
            'question_id' => 'integer',
            'tutor_id' => 'integer',
        ];
    }

    public function getAttachmentUrlAttribute(): ?string
    {
        if (! is_string($this->attachment_path) || ! str_contains($this->attachment_path, '/')) {
            return null;
        }

        return url('/api/questions/'.$this->question_id.'/replies/'.$this->id.'/file');
    }

    public function getAttachmentKindAttribute(): ?string
    {
        $path = strtolower((string) $this->attachment_path);
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

    public function question(): BelongsTo
    {
        return $this->belongsTo(Question::class);
    }

    public function tutor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'tutor_id');
    }
}
