<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Subject;
use App\Models\Track;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class TrackController extends Controller
{
    public function index()
    {
        return Track::query()
            ->with('subjects')
            ->where('division', 'tutor')
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();
    }

    public function update(Request $request, Track $track)
    {
        $data = $request->validate([
            'name' => 'sometimes|required|string|max:120',
            'description' => 'nullable|string|max:2000',
            'is_active' => 'sometimes|boolean',
        ]);

        $track->update($data);

        return $track->fresh()->load('subjects');
    }

    public function storeSubject(Request $request, Track $track)
    {
        if ($track->kind !== 'subjects') {
            throw ValidationException::withMessages([
                'name' => ['This track is one programme. Subjects belong on A/L and O/L only.'],
            ]);
        }

        $data = $request->validate([
            'name' => 'required|string|max:120',
        ]);

        $slug = $this->uniqueSlug(Str::slug($track->slug.'-'.$data['name']));

        $subject = $track->subjects()->create([
            'name' => $data['name'],
            'slug' => $slug,
            'division' => 'tutor',
        ]);

        return response()->json($subject, 201);
    }

    public function updateSubject(Request $request, Subject $subject)
    {
        $data = $request->validate([
            'name' => 'required|string|max:120',
            'slug' => ['sometimes', 'string', 'max:120', Rule::unique('subjects', 'slug')->ignore($subject->id)],
        ]);

        $subject->update($data);

        return $subject->fresh();
    }

    protected function uniqueSlug(string $base): string
    {
        $slug = $base !== '' ? $base : 'subject';
        $candidate = $slug;
        $n = 2;

        while (Subject::where('slug', $candidate)->exists()) {
            $candidate = $slug.'-'.$n;
            $n++;
        }

        return $candidate;
    }
}
