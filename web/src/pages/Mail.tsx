import { useState } from 'react'
import { api } from '../api'
import { DataTable, StatCard } from '../ui'
import { PageFrame, useDeskLoad } from './Desk'

type MailDesk = {
  waiting: Array<{ id: number; name: string; attempts: number; available_at: string; created_at: string }>
  failed: Array<{ id: number; uuid: string; name: string; error: string; failed_at: string }>
  counts: { waiting: number; failed: number }
}

export function MailPage() {
  const { data, error, setError, load } = useDeskLoad<MailDesk | null>('/admin/mail', null)
  const [busy, setBusy] = useState('')

  async function run() {
    setBusy('run')
    setError('')
    try {
      await api('/admin/mail/run', { method: 'POST' })
      await load()
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not send the waiting mail.')
    } finally {
      setBusy('')
    }
  }

  async function retry(uuid?: string) {
    setBusy(uuid ?? 'all')
    setError('')
    try {
      await api(uuid ? `/admin/mail/retry/${uuid}` : '/admin/mail/retry-all', { method: 'POST' })
      await load()
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not queue that mail again.')
    } finally {
      setBusy('')
    }
  }

  return (
    <PageFrame
      eyebrow="Outbox"
      title="Mail queue"
      note="Identity, payment, and staff emails wait here until the worker sends them. Failed rows need a retry."
      error={error}
      action={
        <div className="flex flex-wrap gap-2">
          <button type="button" disabled={busy === 'run'} onClick={() => void run()} className="rounded-xl bg-teal px-3 py-2 text-sm font-semibold text-white disabled:opacity-60">
            {busy === 'run' ? 'Sending…' : 'Send waiting mail'}
          </button>
          <button type="button" disabled={busy === 'all'} onClick={() => void retry()} className="rounded-xl border border-line px-3 py-2 text-sm font-semibold disabled:opacity-60">
            Retry failed
          </button>
        </div>
      }
    >
      <div className="mb-6 grid gap-3 sm:grid-cols-2">
        <StatCard label="Waiting" value={data?.counts.waiting ?? 0} />
        <StatCard label="Failed" value={data?.counts.failed ?? 0} />
      </div>
      <h2 className="mb-3 text-lg font-semibold">Waiting</h2>
      <DataTable columns={['Job', 'Tries', 'Ready']} empty={!data?.waiting.length ? 'Nothing is waiting. Mail already went out, or nothing was queued.' : undefined}>
        {(data?.waiting ?? []).map((row) => (
          <tr key={row.id}>
            <td className="px-4 py-3 font-semibold">{row.name}</td>
            <td className="px-4 py-3">{row.attempts}</td>
            <td className="px-4 py-3 text-muted">{new Date(row.available_at).toLocaleString()}</td>
          </tr>
        ))}
      </DataTable>
      <h2 className="mt-8 mb-3 text-lg font-semibold">Failed</h2>
      <DataTable columns={['Job', 'Error', '']} empty={!data?.failed.length ? 'No failed mail.' : undefined}>
        {(data?.failed ?? []).map((row) => (
          <tr key={row.id} className="align-top">
            <td className="px-4 py-3 font-semibold">{row.name}</td>
            <td className="px-4 py-3 text-muted">{row.error}</td>
            <td className="px-4 py-3 text-right">
              <button type="button" disabled={busy === row.uuid} onClick={() => void retry(row.uuid)} className="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold">
                Retry
              </button>
            </td>
          </tr>
        ))}
      </DataTable>
    </PageFrame>
  )
}
