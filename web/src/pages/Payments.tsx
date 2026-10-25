import { useState } from 'react'
import { api, type PaymentReview } from '../api'
import { FilePreview, PageFrame, useDeskLoad, useFilePreview } from './Desk'

export function PaymentsPage() {
  const { data: payments, error, setError, load } = useDeskLoad<PaymentReview[]>('/admin/pending-payments', [])
  const files = useFilePreview()
  const [busyId, setBusyId] = useState<string | null>(null)

  async function verifyPayment(id: number) {
    setBusyId(`payment-${id}`)
    setError('')
    try {
      await api(`/admin/payments/${id}/verify`, { method: 'POST' })
      await load()
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not mark that payment as received.')
    } finally {
      setBusyId(null)
    }
  }

  return (
    <PageFrame
      eyebrow="Money"
      title="Payments to check"
      note="Bank slips sent from the app. Open the slip, then mark the payment as received."
      error={error || files.error}
    >
      {payments.length === 0 ? <p className="text-sm text-muted">No payments are waiting.</p> : null}
      <ul className="space-y-3">
        {payments.map((payment) => {
          const person = payment.student
          const packageName = payment.subscription?.package?.name ?? 'Package'
          const tutorName = payment.subscription?.tutor?.name ?? 'Teacher'
          const amount = Math.round(Number(payment.amount)).toLocaleString()
          return (
            <li key={payment.id} className="rounded-3xl border border-line bg-white p-4">
              <div className="flex flex-wrap items-center gap-3">
                <div className="min-w-0 flex-1">
                  <p className="font-semibold">{person?.name ?? 'Unknown'} · Rs {amount}</p>
                  <p className="text-sm text-muted">{packageName} · {tutorName}</p>
                </div>
                {payment.has_slip ? (
                  <button
                    type="button"
                    onClick={() => void files.openPrivateFile(`/admin/payments/${payment.id}/file`, `${person?.name ?? 'Payment'} slip`)}
                    className="rounded-xl border border-line px-3 py-2 text-sm font-semibold"
                  >
                    Open slip
                  </button>
                ) : (
                  <p className="text-sm text-muted">No slip photo was stored with this one.</p>
                )}
                <button
                  type="button"
                  disabled={busyId === `payment-${payment.id}`}
                  onClick={() => void verifyPayment(payment.id)}
                  className="rounded-xl bg-teal px-3 py-2 text-sm font-semibold text-white disabled:opacity-60"
                >
                  {busyId === `payment-${payment.id}` ? 'Saving…' : 'Mark as received'}
                </button>
              </div>
            </li>
          )
        })}
      </ul>
      <FilePreview preview={files.preview} onClose={files.closePreview} />
    </PageFrame>
  )
}
