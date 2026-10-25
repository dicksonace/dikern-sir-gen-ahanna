import { type TeacherProfile, roleLabel } from '../api'
import { FilePreview, PageFrame, useDeskLoad, useFilePreview } from './Desk'

const statusLabel: Record<string, string> = {
  pending: 'Waiting for approval',
  approved: 'Approved',
  rejected: 'Not approved',
}

const identityLabel: Record<string, string> = {
  pending: 'Identity document is waiting for a check.',
  approved: 'Identity document is approved.',
  rejected: 'Identity document needs another copy.',
}

export function ProfilesPage() {
  const { data: profiles, error, load } = useDeskLoad<TeacherProfile[]>('/admin/profiles', [])
  const files = useFilePreview()

  return (
    <PageFrame
      eyebrow="People"
      title="Teacher profiles"
      note="Every tutor, lecturer, lawyer, and counsel, including people still waiting. The track pages only list people you have already approved."
      error={error || files.error}
      action={
        <button type="button" onClick={() => void load()} className="rounded-xl border border-line px-3 py-2 text-sm font-semibold">
          Refresh
        </button>
      }
    >
      {profiles.length === 0 ? <p className="text-sm text-muted">No teacher profiles yet.</p> : null}
      <ul className="space-y-3">
        {profiles.map((profile) => {
          const person = profile.user
          const identity = person?.identity_document
          const initial = person?.name?.slice(0, 1).toUpperCase() || '?'
          const side = person?.division === 'law' ? 'Law advice' : 'Learning'
          const details = [profile.qualifications, profile.experience].filter(Boolean).join(' · ')
          return (
            <li key={profile.id} className="rounded-3xl border border-line bg-white p-4">
              <div className="flex flex-wrap items-start gap-3">
                <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-teal/10 text-lg font-semibold text-teal">
                  {initial}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="font-semibold">{person?.name ?? 'Unknown'}</p>
                  <p className="text-sm text-muted">
                    {side} · {roleLabel[person?.role ?? ''] ?? person?.role}
                    {person?.phone ? ` · ${person.phone}` : ''}
                  </p>
                </div>
                <span className="rounded-full bg-sand px-3 py-1 text-xs font-semibold">{statusLabel[profile.status] ?? profile.status}</span>
              </div>
              <p className="mt-3 text-sm leading-6">{profile.bio?.trim() || 'No about text yet.'}</p>
              {details ? <p className="mt-1 text-sm text-muted">{details}</p> : null}
              {profile.subjects && profile.subjects.length > 0 ? (
                <p className="mt-1 text-sm text-muted">{profile.subjects.map((subject) => subject.name).join(' · ')}</p>
              ) : null}
              <div className="mt-3 flex flex-wrap items-center gap-3">
                <p className="text-sm text-muted">{identityLabel[identity?.status ?? ''] ?? 'No identity document yet.'}</p>
                {identity ? (
                  <button
                    type="button"
                    onClick={() => void files.openPrivateFile(`/admin/kyc/${identity.id}/file`, person?.name ?? 'Identity document')}
                    className="rounded-xl border border-line px-3 py-2 text-sm font-semibold"
                  >
                    Open document
                  </button>
                ) : null}
              </div>
              {identity?.status === 'rejected' && identity.note ? <p className="mt-2 text-sm text-muted">{identity.note}</p> : null}
            </li>
          )
        })}
      </ul>
      <FilePreview preview={files.preview} onClose={files.closePreview} />
    </PageFrame>
  )
}
