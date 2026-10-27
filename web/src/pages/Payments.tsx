import { useState } from 'react'
import { api, type PaymentReview } from '../api'
import { Badge, DataTable, FilterPills, Pager, StatCard, statusTone, Toolbar, useTable } from '../ui'
import { FilePreview, PageFrame, useDeskLoad, useFilePreview } from './Desk'

function matchPayment(row: PaymentReview, q: string) {
  return `${row.student?.name ?? ''} ${row.student?.email ?? ''} ${row.subscription?.package?.name ?? ''} ${row.subscription?.tutor?.name ?? ''} ${row.status}`.toLowerCase().includes(q)
}

export function PaymentsPage() {
  const { data: payments, error, setError, load } = useDeskLoad<PaymentReview[]>('/admin/payments', [])
  const files = useFilePreview()
  const [busyId, setBusyId] = useState<string | null>(null)
  const [status, setStatus] = useState('pending')
  const filtered = payments.filter((row) => (status === 'all' ? true : row.status === status))
  const table = useTable(filtered, matchPayment)
  const pending = payments.filter((row) => row.status === 'pending')
  const pendingAmount = pending.reduce((sum, row) => sum + Number(row.amount), 0)

  async function decide(id: number, action: 'verify' | 'reject') {
    setBusyId(`${action}-${id}`)
    setError('')
    try {
      await api(`/admin/payments/${id}/${action}`, { method: 'POST' })
      await load()
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not update that payment.')
    } finally {
      setBusyId(null)
    }
  }

  return (
    <PageFrame
      eyebrow="Money"
      title="Payments"
      note="Bank slips from the app. Open the slip, then mark it received or turn it down. Received payments start the subscription the phone already reads."
      error={error || files.error}
    >
      <div className="mb-6 grid gap-3 sm:grid-cols-4">
        <StatCard label="Waiting" value={pending.length} hint={`Rs ${Math.round(pendingAmount).toLocaleString()}`} />
        <StatCard label="Received" value={payments.filter((row) => row.status === 'verified').length} />
        <StatCard label="Turned down" value={payments.filter((row) => row.status === 'rejected').length} />
        <StatCard label="All slips" value={payments.length} />
      </div>
      <Toolbar q={table.q} onSearch={(value) => { table.setQ(value); table.setPage(1) }} placeholder="Search payer, package, or teacher">
        <FilterPills
          value={status}
          onChange={(id) => { setStatus(id); table.setPage(1) }}
          options={[
            { id: 'pending', label: 'Waiting' },
            { id: 'verified', label: 'Received' },
            { id: 'rejected', label: 'Turned down' },
            { id: 'all', label: 'All' },
          ]}
        />
      </Toolbar>
      <DataTable columns={['Payer', 'Package', 'Amount', 'Slip', 'Status', '']} empty={table.total === 0 ? 'No payments on this filter.' : undefined}>
        {table.rows.map((payment) => {
          const person = payment.student
          const amount = Math.round(Number(payment.amount)).toLocaleString()
          return (
            <tr key={payment.id}>
              <td className="px-4 py-3">
                <p className="font-semibold">{person?.name ?? 'Unknown'}</p>
                <p className="text-muted">{person?.email}</p>
              </td>
              <td className="px-4 py-3 text-muted">
                {payment.subscription?.package?.name ?? 'Package'} · {payment.subscription?.tutor?.name ?? 'Teacher'}
              </td>
              <td className="px-4 py-3 font-semibold tabular-nums">Rs {amount}</td>
              <td className="px-4 py-3">
                {payment.has_slip ? (
                  <button type="button" onClick={() => void files.openPrivateFile(`/admin/payments/${payment.id}/file`, `${person?.name ?? 'Payment'} slip`)} className="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold">
                    Open slip
                  </button>
                ) : (
                  <span className="text-muted">No photo</span>
                )}
              </td>
              <td className="px-4 py-3">
                <Badge tone={statusTone(payment.status)}>{payment.status === 'verified' ? 'Received' : payment.status === 'rejected' ? 'Turned down' : 'Waiting'}</Badge>
              </td>
              <td className="px-4 py-3 text-right">
                {payment.status === 'pending' ? (
                  <div className="flex justify-end gap-2">
                    <button type="button" disabled={busyId === `reject-${payment.id}`} onClick={() => void decide(payment.id, 'reject')} className="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold disabled:opacity-60">
                      Turn down
                    </button>
                    <button type="button" disabled={busyId === `verify-${payment.id}`} onClick={() => void decide(payment.id, 'verify')} className="rounded-lg bg-teal px-3 py-1.5 text-xs font-semibold text-white disabled:opacity-60">
                      Mark received
                    </button>
                  </div>
                ) : null}
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
