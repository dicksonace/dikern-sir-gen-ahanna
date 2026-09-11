<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class Subject extends Model
{
    protected $fillable = ['name', 'slug', 'icon', 'color'];

    public function tutorProfiles(): BelongsToMany
    {
        return $this->belongsToMany(TutorProfile::class, 'subject_tutor');
    }
}
