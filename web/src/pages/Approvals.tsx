import { useState } from 'react'
import { api, roleLabel, type KycDocument, type Overview } from '../api'
import { FilePreview, PageFrame, useDeskLoad, useFilePreview } from './Desk'

const kindLabel: Record<string, string> = {
  nic: 'NIC',
  passport: 'Passport',
  driving_licence: 'Driving licence',
}

export function ApprovalsPage() {
  const overview = useDeskLoad<Overview | null>('/admin/overview', null)
  const kyc = useDeskLoad<KycDocument[]>('/admin/kyc', [])
  const files = useFilePreview()
  const [busyId, setBusyId] = useState<string | null>(null)
  const [notes, setNotes] = useState<Record<number, string>>({})
  const [rowNote, setRowNote] = useState<Record<number, string>>({})
  const error = overview.error || kyc.error || files.error

  async function approve(id: number) {
    setBusyId(`profile-${id}`)
    setRowNote((current) => ({ ...current, [id]: '' }))
    overview.setError('')
    try {
      await api(`/admin/tutors/${id}/approve`, { method: 'POST' })
      await Promise.all([overview.load(), kyc.load()])
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : 'Could not approve.'
      setRowNote((current) => ({ ...current, [id]: message }))
    } finally {
      setBusyId(null)
    }
  }

  async function decideKyc(id: number, decision: 'approve' | 'reject') {
    if (decision === 'reject' && !(notes[id] ?? '').trim()) {
      kyc.setError('Write a short reason before asking them to upload again.')
      return
    }
    setBusyId(`kyc-${id}`)
    kyc.setError('')
    try {
      await api(`/admin/kyc/${id}/${decision}`, {
        method: 'POST',
        body: decision === 'reject' ? JSON.stringify({ note: notes[id] }) : undefined,
      })
      await Promise.all([overview.load(), kyc.load()])
    } catch (caught) {
      kyc.setError(caught instanceof Error ? caught.message : 'Could not review that document.')
    } finally {
      setBusyId(null)
    }
  }

  const pending = overview.data?.pending ?? []

  return (
    <PageFrame
      eyebrow="Checks"
      title="Approvals"
      note="Identity documents first, then the profile. People cannot be found in the app until both are approved."
      error={error}
    >
      <section className="rounded-3xl border border-line bg-white p-6">
        <h2 className="text-xl font-semibold">Identity documents</h2>
        <p className="mt-1 text-sm text-muted">People upload a NIC, passport, or driving licence. Approve it here before you approve their profile.</p>
        {kyc.data.length === 0 ? <p className="mt-4 text-sm text-muted">No documents are waiting.</p> : null}
        <ul className="mt-4 space-y-3">
          {kyc.data.map((document) => {
            const person = document.user
            const side = person?.division === 'law' ? 'Law advice' : 'Learning'
            return (
              <li key={document.id} className="rounded-2xl border border-line p-4">
                <div className="flex flex-wrap items-center gap-3">
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold">{person?.name ?? 'Unknown'}</p>
                    <p className="text-sm text-muted">
                      {side} · {roleLabel[person?.role ?? ''] ?? person?.role} · {kindLabel[document.kind] ?? document.kind}
                    </p>
                  </div>
                  <button type="button" onClick={() => void files.openPrivateFile(`/admin/kyc/${document.id}/file`, person?.name ?? 'Identity document')} className="rounded-xl border border-line px-3 py-2 text-sm font-semibold">
                    Open file
                  </button>
                  <button
                    type="button"
                    disabled={busyId === `kyc-${document.id}`}
                    onClick={() => void decideKyc(document.id, 'approve')}
                    className="rounded-xl bg-teal px-3 py-2 text-sm font-semibold text-white disabled:opacity-60"
                  >
                    Approve
                  </button>
                </div>
                <div className="mt-3 flex gap-2">
                  <input
                    value={notes[document.id] ?? ''}
                    onChange={(event) => setNotes((current) => ({ ...current, [document.id]: event.target.value }))}
                    placeholder="Reason, if you need a clearer copy"
                    className="min-w-0 flex-1 rounded-xl border border-line px-3 py-2 text-sm"
                  />
                  <button
                    type="button"
                    disabled={busyId === `kyc-${document.id}`}
                    onClick={() => void decideKyc(document.id, 'reject')}
                    className="rounded-xl border border-line px-3 py-2 text-sm font-semibold"
                  >
                    Ask again
                  </button>
                </div>
              </li>
            )
          })}
        </ul>
      </section>

      <section className="mt-6 rounded-3xl border border-line bg-white p-6">
        <h2 className="text-xl font-semibold">Waiting for approval</h2>
        <p className="mt-1 text-sm text-muted">Tutors, lecturers, lawyers, and counsel appear here until you approve them.</p>
        {!overview.data ? <p className="mt-4 text-sm text-muted">Loading people…</p> : null}
        {overview.data && pending.length === 0 ? <p className="mt-4 text-sm text-muted">No one is waiting.</p> : null}
        <ul className="mt-4 space-y-3">
          {pending.map((profile) => {
            const person = profile.user
            const initial = person?.name?.slice(0, 1).toUpperCase() || '?'
            const side = person?.division === 'law' ? 'Law advice' : 'Learning'
            const identity = person?.identity_document?.status
            const identityReady = identity === 'approved'
            const identityNote = identityReady
              ? ''
              : identity === 'pending'
                ? 'Their identity document is in the list above. Approve that document first, then approve this profile.'
                : identity === 'rejected'
                  ? 'Their last identity document was not accepted. They need to upload another one before this profile can be approved.'
                  : 'They have not uploaded an identity document yet. The profile can be approved after that document is approved.'
            return (
              <li key={profile.id} className="rounded-2xl border border-line p-4">
                <div className="flex items-center gap-3">
                  <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-teal/10 text-lg font-semibold text-teal">
                    {initial}
                  </span>
                  <div className="min-w-0">
                    <p className="font-semibold">{person?.name ?? 'Unknown'}</p>
                    <p className="text-sm text-muted">
                      {side} · {roleLabel[person?.role ?? ''] ?? person?.role}
                    </p>
                  </div>
                  <button
                    type="button"
                    disabled={!identityReady || busyId === `profile-${profile.id}`}
                    onClick={() => void approve(profile.id)}
                    className="ml-auto rounded-xl bg-teal px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
                  >
                    {busyId === `profile-${profile.id}` ? 'Approving…' : identityReady ? 'Approve' : 'Needs identity first'}
                  </button>
                </div>
                {identityNote ? <p className="mt-3 text-sm text-muted">{identityNote}</p> : null}
                {rowNote[profile.id] ? <p className="mt-3 text-sm font-semibold text-red-800">{rowNote[profile.id]}</p> : null}
              </li>
            )
          })}
        </ul>
      </section>
      <FilePreview preview={files.preview} onClose={files.closePreview} />
    </PageFrame>
  )
}
