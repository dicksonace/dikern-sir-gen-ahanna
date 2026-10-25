import { roleLabel, type AccountRow } from '../api'
import { PageFrame, useDeskLoad } from './Desk'

export function StudentsPage() {
  const { data: accounts, error } = useDeskLoad<AccountRow[]>('/admin/accounts', [])

  return (
    <PageFrame
      eyebrow="People"
      title="Students and clients"
      note="People who learn or ask for advice. Teachers stay in Profiles."
      error={error}
    >
      {accounts.length === 0 ? <p className="text-sm text-muted">No student or client accounts yet.</p> : null}
      <ul className="space-y-3">
        {accounts.map((account) => (
          <li key={account.id} className="flex flex-wrap items-center gap-3 rounded-3xl border border-line bg-white p-4">
            <div className="min-w-0 flex-1">
              <p className="font-semibold">{account.name}</p>
              <p className="text-sm text-muted">
                {account.division === 'law' ? 'Law advice' : 'Learning'} · {roleLabel[account.role] ?? account.role}
                {account.phone ? ` · ${account.phone}` : ''}
              </p>
              <p className="text-sm text-muted">{account.email}</p>
            </div>
          </li>
        ))}
      </ul>
    </PageFrame>
  )
}
