import { useState } from 'react'
import { type TeacherProfile, roleLabel } from '../api'
import { Badge, DataTable, FilterPills, Pager, StatCard, statusTone, Toolbar, useTable } from '../ui'
import { FilePreview, PageFrame, useDeskLoad, useFilePreview } from './Desk'

const statusLabel: Record<string, string> = {
  pending: 'Waiting',
  approved: 'Approved',
  rejected: 'Not approved',
}

function matchProfile(row: TeacherProfile, q: string) {
  const person = row.user
  return `${person?.name ?? ''} ${person?.email ?? ''} ${person?.phone ?? ''} ${person?.role ?? ''} ${row.bio ?? ''} ${row.subjects?.map((subject) => subject.name).join(' ') ?? ''}`.toLowerCase().includes(q)
}

export function ProfilesPage() {
  const { data: profiles, error, load } = useDeskLoad<TeacherProfile[]>('/admin/profiles', [])
  const files = useFilePreview()
  const [status, setStatus] = useState('all')
  const filtered = profiles.filter((row) => (status === 'all' ? true : row.status === status))
  const table = useTable(filtered, matchProfile)

  return (
    <PageFrame
      eyebrow="People"
      title="Teacher profiles"
      note="Every tutor, lecturer, lawyer, and counsel. Track pages only list people you have already approved."
      error={error || files.error}
      action={
        <button type="button" onClick={() => void load()} className="rounded-xl border border-line px-3 py-2 text-sm font-semibold">
          Refresh
        </button>
      }
    >
      <div className="mb-6 grid gap-3 sm:grid-cols-4">
        <StatCard label="Waiting" value={profiles.filter((row) => row.status === 'pending').length} />
        <StatCard label="Approved" value={profiles.filter((row) => row.status === 'approved').length} />
        <StatCard label="Learning" value={profiles.filter((row) => row.user?.division !== 'law').length} />
        <StatCard label="Law" value={profiles.filter((row) => row.user?.division === 'law').length} />
      </div>
      <Toolbar q={table.q} onSearch={(value) => { table.setQ(value); table.setPage(1) }} placeholder="Search name, email, or subject">
        <FilterPills
          value={status}
          onChange={(id) => { setStatus(id); table.setPage(1) }}
          options={[
            { id: 'all', label: 'All' },
            { id: 'pending', label: 'Waiting' },
            { id: 'approved', label: 'Approved' },
            { id: 'rejected', label: 'Not approved' },
          ]}
        />
      </Toolbar>
      <DataTable columns={['Teacher', 'Role', 'Subjects', 'Identity', 'Status']} empty={table.total === 0 ? 'No profiles match.' : undefined}>
        {table.rows.map((profile) => {
          const person = profile.user
          const identity = person?.identity_document
          return (
            <tr key={profile.id} className="align-top">
              <td className="px-4 py-3">
                <p className="font-semibold">{person?.name ?? 'Unknown'}</p>
                <p className="text-muted">{person?.email}{person?.phone ? ` · ${person.phone}` : ''}</p>
                <p className="mt-1 line-clamp-2 text-muted">{profile.bio?.trim() || 'No about text yet.'}</p>
              </td>
              <td className="px-4 py-3">
                {person?.division === 'law' ? 'Law' : 'Learning'}
                <br />
                <span className="text-muted">{roleLabel[person?.role ?? ''] ?? person?.role}</span>
              </td>
              <td className="px-4 py-3 text-muted">{profile.subjects?.map((subject) => subject.name).join(', ') || '—'}</td>
              <td className="px-4 py-3">
                {identity ? (
                  <button type="button" onClick={() => void files.openPrivateFile(`/admin/kyc/${identity.id}/file`, person?.name ?? 'Identity document')} className="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold">
                    {identity.status === 'approved' ? 'Open · approved' : identity.status === 'rejected' ? 'Open · ask again' : 'Open · waiting'}
                  </button>
                ) : (
                  <span className="text-muted">None</span>
                )}
              </td>
              <td className="px-4 py-3">
                <Badge tone={statusTone(profile.status)}>{statusLabel[profile.status] ?? profile.status}</Badge>
              </td>
            </tr>
          )
        })}
      </DataTable>
      <Pager page={table.page} pages={table.pages} total={table.total} pageSize={table.pageSize} onPage={table.setPage} />
      <FilePreview preview={files.preview} onClose={files.closePreview} />
    </PageFrame>
  )
}
