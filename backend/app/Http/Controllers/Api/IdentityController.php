<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\IdentityDocument;
use App\Models\User;
use App\Support\AccountMailer;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class IdentityController extends Controller
{
    public function show(Request $request)
    {
        return response()->json(
            $request->user()->identityDocument
        );
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'kind' => 'required|in:nic,passport,driving_licence',
            'document' => 'required|file|mimes:jpg,jpeg,png,webp,pdf|max:5120',
        ]);

        $user = $request->user();
        $file = $request->file('document');
        $safeName = preg_replace('/[^A-Za-z0-9._-]/', '_', $file->getClientOriginalName()) ?: 'identity';
        $path = $file->storeAs('kyc/'.$user->id, now()->format('YmdHis').'-'.$safeName, 'local');

        IdentityDocument::where('user_id', $user->id)->where('status', 'pending')->update([
            'status' => 'replaced',
        ]);

        $document = IdentityDocument::create([
            'user_id' => $user->id,
            'kind' => $data['kind'],
            'path' => $path,
            'original_name' => $file->getClientOriginalName(),
            'status' => 'pending',
        ]);

        AccountMailer::queueKycReceived($user);
        AccountMailer::queueKycForAdmins($user);

        return response()->json($document, 201);
    }

    public function pending()
    {
        return IdentityDocument::with('user:id,name,email,role,division')
            ->where('status', 'pending')
            ->latest()
            ->get();
    }

    public function file(int $id)
    {
        $document = IdentityDocument::findOrFail($id);

        if (! Storage::disk('local')->exists($document->path)) {
            abort(404);
        }

        $name = preg_replace('/[^A-Za-z0-9._-]/', '_', (string) $document->original_name) ?: 'identity';

        return Storage::disk('local')->response($document->path, $name);
    }

    public function approve(Request $request, int $id)
    {
        $document = $this->review($request, $id, 'approved', null);
        AccountMailer::queueKycDecision($document->user, 'approved', null);

        return response()->json($document);
    }

    public function reject(Request $request, int $id)
    {
        $data = $request->validate([
            'note' => 'required|string|max:500',
        ]);

        $document = $this->review($request, $id, 'rejected', $data['note']);
        AccountMailer::queueKycDecision($document->user, 'rejected', $data['note']);

        return response()->json($document);
    }

    protected function review(Request $request, int $id, string $status, ?string $note): IdentityDocument
    {
        $document = IdentityDocument::with('user')->findOrFail($id);

        if ($document->status !== 'pending') {
            throw ValidationException::withMessages([
                'status' => ['This document has already been reviewed.'],
            ]);
        }

        $document->update([
            'status' => $status,
            'note' => $note,
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
        ]);

        return $document->fresh()->load('user:id,name,email,role,division');
    }
}
