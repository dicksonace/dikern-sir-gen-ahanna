import { useState } from 'react'
import { api, roleLabel, type KycDocument, type Overview } from '../api'
import { DataTable, Pager, StatCard, Toolbar, useTable } from '../ui'
import { FilePreview, PageFrame, useDeskLoad, useFilePreview } from './Desk'

const kindLabel: Record<string, string> = {
  nic: 'NIC',
  passport: 'Passport',
  driving_licence: 'Driving licence',
}

function matchKyc(row: KycDocument, q: string) {
  return `${row.user?.name ?? ''} ${row.user?.email ?? ''} ${row.kind} ${row.user?.role ?? ''}`.toLowerCase().includes(q)
}

function matchPending(row: Overview['pending'][number], q: string) {
  return `${row.user?.name ?? ''} ${row.user?.email ?? ''} ${row.user?.role ?? ''}`.toLowerCase().includes(q)
}

export function ApprovalsPage() {
  const overview = useDeskLoad<Overview | null>('/admin/overview', null)
  const kyc = useDeskLoad<KycDocument[]>('/admin/kyc', [])
  const files = useFilePreview()
  const [busyId, setBusyId] = useState<string | null>(null)
  const [notes, setNotes] = useState<Record<number, string>>({})
  const [rowNote, setRowNote] = useState<Record<number, string>>({})
  const pending = overview.data?.pending ?? []
  const kycTable = useTable(kyc.data, matchKyc, 8)
  const pendingTable = useTable(pending, matchPending, 8)
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

  return (
    <PageFrame
      eyebrow="Checks"
      title="Approvals"
      note="Identity documents first, then the profile. People cannot be found in the app until both are approved."
      error={error}
    >
      <div className="mb-6 grid gap-3 sm:grid-cols-3">
        <StatCard label="Identity waiting" value={kyc.data.length} />
        <StatCard label="Profiles waiting" value={pending.length} />
        <StatCard label="Ready to approve" value={pending.filter((row) => row.user?.identity_document?.status === 'approved').length} />
      </div>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold">Identity documents</h2>
        <Toolbar q={kycTable.q} onSearch={(value) => { kycTable.setQ(value); kycTable.setPage(1) }} placeholder="Search identity documents" />
        <DataTable columns={['Person', 'Document', 'Reason', '']} empty={kycTable.total === 0 ? 'No documents are waiting.' : undefined}>
          {kycTable.rows.map((document) => {
            const person = document.user
            return (
              <tr key={document.id} className="align-top">
                <td className="px-4 py-3">
                  <p className="font-semibold">{person?.name ?? 'Unknown'}</p>
                  <p className="text-muted">
                    {person?.division === 'law' ? 'Law' : 'Learning'} · {roleLabel[person?.role ?? ''] ?? person?.role}
                  </p>
                </td>
                <td className="px-4 py-3">{kindLabel[document.kind] ?? document.kind}</td>
                <td className="px-4 py-3">
                  <input
                    value={notes[document.id] ?? ''}
                    onChange={(event) => setNotes((current) => ({ ...current, [document.id]: event.target.value }))}
                    placeholder="Reason, if you need a clearer copy"
                    className="w-full min-w-[180px] rounded-xl border border-line px-3 py-2 text-sm"
                  />
                </td>
                <td className="px-4 py-3 text-right">
                  <div className="flex justify-end gap-2">
                    <button type="button" onClick={() => void files.openPrivateFile(`/admin/kyc/${document.id}/file`, person?.name ?? 'Identity document')} className="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold">
                      Open
                    </button>
                    <button type="button" disabled={busyId === `kyc-${document.id}`} onClick={() => void decideKyc(document.id, 'reject')} className="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold">
                      Ask again
                    </button>
                    <button type="button" disabled={busyId === `kyc-${document.id}`} onClick={() => void decideKyc(document.id, 'approve')} className="rounded-lg bg-teal px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-60">
                      Approve
                    </button>
                  </div>
                </td>
              </tr>
            )
          })}
        </DataTable>
        <Pager page={kycTable.page} pages={kycTable.pages} total={kycTable.total} pageSize={kycTable.pageSize} onPage={kycTable.setPage} />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Waiting for approval</h2>
        <Toolbar q={pendingTable.q} onSearch={(value) => { pendingTable.setQ(value); pendingTable.setPage(1) }} placeholder="Search waiting profiles" />
        <DataTable columns={['Person', 'Identity', '']} empty={pendingTable.total === 0 ? 'No one is waiting.' : undefined}>
          {pendingTable.rows.map((profile) => {
            const person = profile.user
            const identity = person?.identity_document?.status
            const identityReady = identity === 'approved'
            const identityNote = identityReady
              ? 'Identity approved'
              : identity === 'pending'
                ? 'Approve the identity document first'
                : identity === 'rejected'
                  ? 'They need to upload another identity document'
                  : 'No identity document yet'
            return (
              <tr key={profile.id}>
                <td className="px-4 py-3">
                  <p className="font-semibold">{person?.name ?? 'Unknown'}</p>
                  <p className="text-muted">
                    {person?.division === 'law' ? 'Law' : 'Learning'} · {roleLabel[person?.role ?? ''] ?? person?.role}
                  </p>
                  {rowNote[profile.id] ? <p className="mt-1 text-sm font-semibold text-red-800">{rowNote[profile.id]}</p> : null}
                </td>
                <td className="px-4 py-3 text-muted">{identityNote}</td>
                <td className="px-4 py-3 text-right">
                  <button
                    type="button"
                    disabled={!identityReady || busyId === `profile-${profile.id}`}
                    onClick={() => void approve(profile.id)}
                    className="rounded-xl bg-teal px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
                  >
                    {busyId === `profile-${profile.id}` ? 'Approving…' : identityReady ? 'Approve' : 'Needs identity first'}
                  </button>
                </td>
              </tr>
            )
          })}
        </DataTable>
        <Pager page={pendingTable.page} pages={pendingTable.pages} total={pendingTable.total} pageSize={pendingTable.pageSize} onPage={pendingTable.setPage} />
      </section>
      <FilePreview preview={files.preview} onClose={files.closePreview} />
    </PageFrame>
  )
}
