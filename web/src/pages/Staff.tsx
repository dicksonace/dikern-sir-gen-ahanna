import { useState, type FormEvent } from 'react'
import { ADMIN_PAGES, api, type AdminUser } from '../api'
import { useAuth } from '../auth'
import { Badge, DataTable, Pager, StatCard, Toolbar, useTable } from '../ui'
import { PageFrame, useDeskLoad } from './Desk'

function matchStaff(row: AdminUser, q: string) {
  return `${row.name} ${row.email} ${row.phone ?? ''}`.toLowerCase().includes(q)
}

export function StaffPage() {
  const { user } = useAuth()
  const { data: staff, error, setError, load } = useDeskLoad<AdminUser[]>('/admin/staff', [])
  const table = useTable(staff, matchStaff, 8)
  const [busy, setBusy] = useState('')
  const [form, setForm] = useState({
    name: '',
    email: '',
    phone: '',
    password: '',
    pages: ['dashboard', 'account'] as string[],
  })

  const assignable = ADMIN_PAGES.filter((page) => page.id !== 'account')

  function togglePage(id: string) {
    setForm((current) => ({
      ...current,
      pages: current.pages.includes(id) ? current.pages.filter((page) => page !== id) : [...current.pages, id],
    }))
  }

  async function createStaff(event: FormEvent) {
    event.preventDefault()
    setBusy('create')
    setError('')
    try {
      await api('/admin/staff', { method: 'POST', body: JSON.stringify(form) })
      setForm({ name: '', email: '', phone: '', password: '', pages: ['dashboard', 'account'] })
      await load()
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not add that staff account.')
    } finally {
      setBusy('')
    }
  }

  async function savePages(row: AdminUser, pages: string[]) {
    setBusy(`pages-${row.id}`)
    setError('')
    try {
      await api(`/admin/staff/${row.id}`, { method: 'PUT', body: JSON.stringify({ pages }) })
      await load()
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not update pages.')
    } finally {
      setBusy('')
    }
  }

  async function removeStaff(row: AdminUser) {
    setBusy(`del-${row.id}`)
    setError('')
    try {
      await api(`/admin/staff/${row.id}`, { method: 'DELETE' })
      await load()
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not remove that account.')
    } finally {
      setBusy('')
    }
  }

  return (
    <PageFrame
      eyebrow="Desk"
      title="Staff"
      note="Add people who run this website. Tick the pages they may open. A welcome email is queued, so tell them the password in person."
      error={error}
    >
      <div className="mb-6 grid gap-3 sm:grid-cols-3">
        <StatCard label="Staff" value={staff.length} />
        <StatCard label="Full access" value={staff.filter((row) => row.pages == null).length} />
        <StatCard label="Limited" value={staff.filter((row) => row.pages != null).length} />
      </div>
      <div className="grid items-start gap-6 xl:grid-cols-[minmax(0,1.4fr)_minmax(0,22rem)]">
        <section>
          <Toolbar q={table.q} onSearch={(value) => { table.setQ(value); table.setPage(1) }} placeholder="Search staff" />
          <DataTable columns={['Person', 'Pages', '']} empty={table.total === 0 ? 'No staff yet.' : undefined}>
            {table.rows.map((row) => (
              <tr key={row.id} className="align-top">
                <td className="px-4 py-3">
                  <p className="font-semibold">{row.name}</p>
                  <p className="text-muted">{row.email}</p>
                </td>
                <td className="px-4 py-3">
                  {row.pages == null ? (
                    <Badge tone="teal">Every page</Badge>
                  ) : (
                    <div className="flex max-w-xl flex-wrap gap-2">
                      {assignable.map((page) => {
                        const on = row.pages?.includes(page.id)
                        return (
                          <button
                            key={page.id}
                            type="button"
                            disabled={busy === `pages-${row.id}`}
                            onClick={() => {
                          const currentPages = row.pages ?? ADMIN_PAGES.map((item) => item.id)
                          const next = on ? currentPages.filter((id) => id !== page.id) : [...currentPages, page.id]
                          void savePages(row, next.includes('account') ? next : [...next, 'account'])
                        }}
                            className={`rounded-full px-2.5 py-1 text-xs font-semibold ${on ? 'bg-teal text-white' : 'border border-line'}`}
                          >
                            {page.label}
                          </button>
                        )
                      })}
                    </div>
                  )}
                </td>
                <td className="px-4 py-3 text-right">
                  {row.id !== user?.id ? (
                    <button type="button" disabled={busy === `del-${row.id}`} onClick={() => void removeStaff(row)} className="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold">
                      Remove
                    </button>
                  ) : (
                    <span className="text-xs text-muted">You</span>
                  )}
                </td>
              </tr>
            ))}
          </DataTable>
          <Pager page={table.page} pages={table.pages} total={table.total} pageSize={table.pageSize} onPage={table.setPage} />
        </section>
        <form onSubmit={(event) => void createStaff(event)} className="rounded-3xl border border-line bg-white p-5">
          <h2 className="text-lg font-semibold">Add staff</h2>
          <input value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} placeholder="Name" className="mt-4 w-full rounded-xl border border-line px-3 py-2.5" required />
          <input value={form.email} onChange={(event) => setForm({ ...form, email: event.target.value })} type="email" placeholder="Email" className="mt-3 w-full rounded-xl border border-line px-3 py-2.5" required />
          <input value={form.phone} onChange={(event) => setForm({ ...form, phone: event.target.value })} placeholder="Phone" className="mt-3 w-full rounded-xl border border-line px-3 py-2.5" />
          <input value={form.password} onChange={(event) => setForm({ ...form, password: event.target.value })} type="password" minLength={6} placeholder="Temporary password" className="mt-3 w-full rounded-xl border border-line px-3 py-2.5" required />
          <p className="mt-4 text-sm font-semibold">Pages they can open</p>
          <div className="mt-2 flex flex-wrap gap-2">
            {assignable.map((page) => (
              <button
                key={page.id}
                type="button"
                onClick={() => togglePage(page.id)}
                className={`rounded-full px-3 py-1.5 text-xs font-semibold ${form.pages.includes(page.id) ? 'bg-teal text-white' : 'border border-line'}`}
              >
                {page.label}
              </button>
            ))}
          </div>
          <button type="submit" disabled={busy === 'create'} className="mt-5 w-full rounded-xl bg-teal px-4 py-3 font-semibold text-white disabled:opacity-60">
            {busy === 'create' ? 'Saving…' : 'Add staff'}
          </button>
        </form>
      </div>
    </PageFrame>
  )
}
