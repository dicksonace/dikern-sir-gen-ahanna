<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class IdentityDocument extends Model
{
    protected $fillable = [
        'user_id',
        'kind',
        'path',
        'original_name',
        'status',
        'note',
        'reviewed_by',
        'reviewed_at',
    ];

    protected $hidden = [
        'path',
    ];

    protected function casts(): array
    {
        return [
            'reviewed_at' => 'datetime',
        ];
    }

    public function scopeForAccount(Builder $query): void
    {
        $query->select([
            'identity_documents.id',
            'identity_documents.user_id',
            'identity_documents.kind',
            'identity_documents.status',
            'identity_documents.note',
            'identity_documents.created_at',
        ]);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }
}
