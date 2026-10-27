import { useState, type FormEvent } from 'react'
import { api, type PackageRow } from '../api'
import { Badge, DataTable, FilterPills, Pager, StatCard, Toolbar, useTable } from '../ui'
import { PageFrame, useDeskLoad } from './Desk'

type Area = { id: number; name: string; slug: string }

function matchPackage(row: PackageRow, q: string) {
  return `${row.name} ${row.division} ${row.description ?? ''}`.toLowerCase().includes(q)
}

export function CatalogPage() {
  const packages = useDeskLoad<PackageRow[]>('/admin/packages', [])
  const areas = useDeskLoad<Area[]>('/subjects?division=law', [])
  const [busy, setBusy] = useState('')
  const [areaName, setAreaName] = useState('')
  const [form, setForm] = useState({
    name: '',
    division: 'tutor' as 'tutor' | 'law',
    description: '',
    price: '8500',
    weekly_hours: '2',
    includes_instant_questions: true,
    includes_screen_share: true,
  })
  const [filter, setFilter] = useState('all')
  const filtered = packages.data.filter((row) => (filter === 'all' ? true : row.division === filter))
  const table = useTable(filtered, matchPackage, 8)

  async function savePackage(event: FormEvent) {
    event.preventDefault()
    setBusy('create')
    packages.setError('')
    try {
      await api('/admin/packages', {
        method: 'POST',
        body: JSON.stringify({
          ...form,
          price: Number(form.price),
          weekly_hours: Number(form.weekly_hours),
        }),
      })
      setForm({ ...form, name: '', description: '' })
      await packages.load()
    } catch (caught) {
      packages.setError(caught instanceof Error ? caught.message : 'Could not create that package.')
    } finally {
      setBusy('')
    }
  }

  async function togglePackage(row: PackageRow) {
    setBusy(`pkg-${row.id}`)
    packages.setError('')
    try {
      await api(`/admin/packages/${row.id}`, {
        method: 'PUT',
        body: JSON.stringify({ is_active: !row.is_active }),
      })
      await packages.load()
    } catch (caught) {
      packages.setError(caught instanceof Error ? caught.message : 'Could not update that package.')
    } finally {
      setBusy('')
    }
  }

  async function addArea(event: FormEvent) {
    event.preventDefault()
    setBusy('area')
    areas.setError('')
    try {
      await api('/admin/practice-areas', { method: 'POST', body: JSON.stringify({ name: areaName }) })
      setAreaName('')
      window.dispatchEvent(new Event('admin-nav-refresh'))
      await areas.load()
    } catch (caught) {
      areas.setError(caught instanceof Error ? caught.message : 'Could not add that practice area.')
    } finally {
      setBusy('')
    }
  }

  async function refreshCache() {
    setBusy('cache')
    packages.setError('')
    try {
      await api('/admin/cache/refresh', { method: 'POST' })
    } catch (caught) {
      packages.setError(caught instanceof Error ? caught.message : 'Could not refresh the app catalog.')
    } finally {
      setBusy('')
    }
  }

  const error = packages.error || areas.error
  const learningPkgs = packages.data.filter((row) => row.division === 'tutor')
  const lawPkgs = packages.data.filter((row) => row.division === 'law')

  return (
    <PageFrame
      eyebrow="App feed"
      title="Catalog"
      note="Packages and practice areas the phone reads. Turn a package off to hide it from Subscribe. Refresh cache after a big edit so the app list updates immediately."
      error={error}
      action={
        <button type="button" disabled={busy === 'cache'} onClick={() => void refreshCache()} className="rounded-xl border border-line px-3 py-2 text-sm font-semibold disabled:opacity-60">
          {busy === 'cache' ? 'Refreshing…' : 'Refresh app lists'}
        </button>
      }
    >
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Learning packages" value={learningPkgs.length} hint={`${learningPkgs.filter((row) => row.is_active).length} live`} />
        <StatCard label="Law packages" value={lawPkgs.length} hint={`${lawPkgs.filter((row) => row.is_active).length} live`} />
        <StatCard label="Practice areas" value={areas.data.length} />
        <StatCard label="Hidden packages" value={packages.data.filter((row) => !row.is_active).length} />
      </div>

      <div className="mt-6 grid items-start gap-6 xl:grid-cols-[minmax(0,1.4fr)_340px]">
        <section>
          <Toolbar q={table.q} onSearch={(value) => { table.setQ(value); table.setPage(1) }} placeholder="Search packages">
            <FilterPills
              value={filter}
              onChange={(id) => { setFilter(id); table.setPage(1) }}
              options={[
                { id: 'all', label: 'All' },
                { id: 'tutor', label: 'Learning' },
                { id: 'law', label: 'Law' },
              ]}
            />
          </Toolbar>
          <DataTable columns={['Package', 'Side', 'Price', 'Hours', 'Live', '']} empty={table.total === 0 ? 'No packages match.' : undefined}>
            {table.rows.map((row) => (
              <tr key={row.id} className="align-top">
                <td className="px-4 py-3">
                  <p className="font-semibold">{row.name}</p>
                  <p className="mt-1 text-muted">{row.description}</p>
                </td>
                <td className="px-4 py-3">{row.division === 'law' ? 'Law' : 'Learning'}</td>
                <td className="px-4 py-3 tabular-nums">Rs {Math.round(Number(row.price)).toLocaleString()}</td>
                <td className="px-4 py-3 tabular-nums">{row.weekly_hours}</td>
                <td className="px-4 py-3">
                  <Badge tone={row.is_active ? 'teal' : 'sand'}>{row.is_active ? 'Live' : 'Hidden'}</Badge>
                </td>
                <td className="px-4 py-3 text-right">
                  <button
                    type="button"
                    disabled={busy === `pkg-${row.id}`}
                    onClick={() => void togglePackage(row)}
                    className="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold"
                  >
                    {row.is_active ? 'Hide in app' : 'Show in app'}
                  </button>
                </td>
              </tr>
            ))}
          </DataTable>
          <Pager page={table.page} pages={table.pages} total={table.total} pageSize={table.pageSize} onPage={table.setPage} />
        </section>

        <div className="space-y-6">
          <section className="rounded-3xl border border-line bg-white p-5">
            <h2 className="text-lg font-semibold">New package</h2>
            <p className="mt-1 text-sm text-muted">Students pick this on a tutor page. Law packages appear on every practice area.</p>
            <form onSubmit={(event) => void savePackage(event)} className="mt-4 space-y-3">
              <input value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} placeholder="Name" className="w-full rounded-xl border border-line px-3 py-2.5" required />
              <select value={form.division} onChange={(event) => setForm({ ...form, division: event.target.value as 'tutor' | 'law' })} className="w-full rounded-xl border border-line px-3 py-2.5">
                <option value="tutor">Learning</option>
                <option value="law">Law advice</option>
              </select>
              <textarea value={form.description} onChange={(event) => setForm({ ...form, description: event.target.value })} placeholder="What this includes" rows={3} className="w-full rounded-xl border border-line px-3 py-2.5" />
              <div className="grid grid-cols-2 gap-3">
                <input value={form.price} onChange={(event) => setForm({ ...form, price: event.target.value })} type="number" min="0" step="100" className="rounded-xl border border-line px-3 py-2.5" required />
                <input value={form.weekly_hours} onChange={(event) => setForm({ ...form, weekly_hours: event.target.value })} type="number" min="0" max="40" className="rounded-xl border border-line px-3 py-2.5" />
              </div>
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={form.includes_instant_questions} onChange={(event) => setForm({ ...form, includes_instant_questions: event.target.checked })} />
                Instant questions
              </label>
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" checked={form.includes_screen_share} onChange={(event) => setForm({ ...form, includes_screen_share: event.target.checked })} />
                Screen share
              </label>
              <button type="submit" disabled={busy === 'create'} className="w-full rounded-xl bg-teal px-4 py-3 font-semibold text-white disabled:opacity-60">
                {busy === 'create' ? 'Saving…' : 'Add package'}
              </button>
            </form>
          </section>

          <section className="rounded-3xl border border-line bg-white p-5">
            <h2 className="text-lg font-semibold">Practice areas</h2>
            <p className="mt-1 text-sm text-muted">Adds a Law advice item in the app and in this sidebar.</p>
            <ul className="mt-3 space-y-2 text-sm">
              {areas.data.map((area) => (
                <li key={area.id} className="rounded-xl bg-sand px-3 py-2 font-semibold">{area.name}</li>
              ))}
            </ul>
            <form onSubmit={(event) => void addArea(event)} className="mt-4 space-y-3">
              <input value={areaName} onChange={(event) => setAreaName(event.target.value)} placeholder="For example Tax" className="w-full rounded-xl border border-line px-3 py-2.5" required />
              <button type="submit" disabled={busy === 'area'} className="w-full rounded-xl border border-teal px-4 py-3 font-semibold text-teal disabled:opacity-60">
                {busy === 'area' ? 'Saving…' : 'Add practice area'}
              </button>
            </form>
          </section>
        </div>
      </div>
    </PageFrame>
  )
}
