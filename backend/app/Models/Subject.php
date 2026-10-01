<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class Subject extends Model
{
    protected $fillable = ['name', 'slug', 'division', 'icon', 'color', 'track_id'];

    public function track(): BelongsTo
    {
        return $this->belongsTo(Track::class);
    }

    public function tutorProfiles(): BelongsToMany
    {
        return $this->belongsToMany(TutorProfile::class, 'subject_tutor');
    }
}
