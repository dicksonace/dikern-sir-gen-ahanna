import { useEffect, useState, type FormEvent } from 'react'
import { useParams } from 'react-router-dom'
import { api, ApiError } from '../api'
import { AdminShell } from '../components/AdminShell'
import { DataTable, Pager, StatCard, Toolbar, useTable } from '../ui'

type Area = { id: number; name: string; slug: string; color: string | null }
type Person = {
  id: number
  bio: string | null
  qualifications: string | null
  experience: string | null
  satisfaction_points: number
  available_slots: string[] | null
  user: { name: string; email: string; role: string; phone: string | null } | null
}
type AdvicePackage = { id: number; name: string; description: string | null; price: number }

const roleLabel: Record<string, string> = {
  lawyer: 'Lawyer',
  counsel: 'Legal counsel',
}

export function LawPage() {
  const { slug } = useParams()
  const [areas, setAreas] = useState<Area[]>([])
  const [people, setPeople] = useState<Person[]>([])
  const [packages, setPackages] = useState<AdvicePackage[]>([])
  const [name, setName] = useState('')
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  const area = areas.find((item) => item.slug === slug) ?? null

  useEffect(() => {
    if (!slug) return
    let cancelled = false
    setError('')
    void Promise.all([
      api<Area[]>('/subjects?division=law'),
      api<Person[]>(`/tutors?division=law&subject=${encodeURIComponent(slug)}`),
      api<AdvicePackage[]>('/packages?division=law'),
    ])
      .then(([nextAreas, nextPeople, nextPackages]) => {
        if (cancelled) return
        setAreas(nextAreas)
        setPeople(nextPeople)
        setPackages(nextPackages)
        const current = nextAreas.find((item) => item.slug === slug)
        setName(current?.name ?? '')
      })
      .catch((caught: unknown) => {
        if (!cancelled) setError(caught instanceof Error ? caught.message : 'Could not load this practice area.')
      })
    return () => {
      cancelled = true
    }
  }, [slug])

  async function rename(event: FormEvent) {
    event.preventDefault()
    if (!area) return
    setSaving(true)
    setError('')
    try {
      const updated = await api<Area>(`/admin/subjects/${area.id}`, {
        method: 'PUT',
        body: JSON.stringify({ name }),
      })
      setAreas((rows) => rows.map((row) => (row.id === updated.id ? { ...row, name: updated.name } : row)))
      window.dispatchEvent(new Event('admin-nav-refresh'))
    } catch (caught) {
      setError(caught instanceof ApiError ? caught.message : 'Could not rename this practice area.')
    } finally {
      setSaving(false)
    }
  }

  const lawyers = people.filter((person) => person.user?.role !== 'counsel')
  const counsel = people.filter((person) => person.user?.role === 'counsel')
  const accent = area?.color || '#0D7377'

  return (
    <AdminShell>
      <div className="mx-auto max-w-7xl">
        <div className="overflow-hidden rounded-3xl border border-line bg-white">
          <div className="h-2" style={{ background: accent }} />
          <div className="p-6 md:p-8">
            <p className="text-sm font-semibold text-teal">Law advice</p>
            <h1 className="mt-1 text-3xl font-semibold">{area?.name ?? 'Practice area'}</h1>
            <p className="mt-2 max-w-2xl text-muted">
              Clients book a lawyer or legal counsel in this area. It is not an exam track.
            </p>
            <div className="mt-6 grid gap-3 sm:grid-cols-3">
              <StatCard label="Lawyers" value={area ? lawyers.length : '—'} />
              <StatCard label="Legal counsel" value={area ? counsel.length : '—'} />
              <StatCard label="Packages" value={packages.length || '—'} />
            </div>
          </div>
        </div>

        {error ? <p className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-800">{error}</p> : null}

        <div className="mt-6 grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
          <div className="space-y-6">
            <PeopleGroup title="Lawyers" hint="One-to-one advice" people={lawyers} ready={area !== null} />
            <PeopleGroup title="Legal counsel" hint="Written guidance" people={counsel} ready={area !== null} />
          </div>
          <div className="space-y-6">
            <section className="rounded-3xl border border-line bg-white p-5">
              <h2 className="text-lg font-semibold">Practice area</h2>
              <p className="mt-1 text-sm text-muted">The name clients see in the app.</p>
              <form onSubmit={(event) => void rename(event)} className="mt-4 space-y-3">
                <input
                  value={name}
                  onChange={(event) => setName(event.target.value)}
                  className="w-full rounded-xl border border-line px-3 py-3"
                  required
                />
                <button
                  type="submit"
                  disabled={saving || !area}
                  className="w-full rounded-xl bg-teal px-4 py-3 font-semibold text-white disabled:opacity-60"
                >
                  {saving ? 'Saving…' : 'Save name'}
                </button>
              </form>
            </section>
            <section className="rounded-3xl border border-line bg-white p-5">
              <h2 className="text-lg font-semibold">Consultation packages</h2>
              <p className="mt-1 text-sm text-muted">Shared by every practice area.</p>
              <ul className="mt-4 space-y-3">
                {packages.map((item) => (
                  <li key={item.id} className="rounded-2xl bg-sand px-4 py-3">
                    <p className="font-semibold">{item.name}</p>
                    <p className="mt-1 text-sm text-muted">{item.description}</p>
                    <p className="mt-2 text-sm font-semibold text-teal">Rs {Number(item.price).toLocaleString()}</p>
                  </li>
                ))}
                {packages.length === 0 ? <li className="text-sm text-muted">No law packages yet.</li> : null}
              </ul>
            </section>
          </div>
        </div>
      </div>
    </AdminShell>
  )
}

function matchPerson(row: Person, q: string) {
  return `${row.user?.name ?? ''} ${row.user?.email ?? ''} ${row.bio ?? ''} ${row.qualifications ?? ''}`.toLowerCase().includes(q)
}

function PeopleGroup({
  title,
  hint,
  people,
  ready,
}: {
  title: string
  hint: string
  people: Person[]
  ready: boolean
}) {
  const table = useTable(people, matchPerson, 8)
  return (
    <section>
      <h2 className="text-lg font-semibold">{title}</h2>
      <p className="mt-1 mb-3 text-sm text-muted">{hint}</p>
      {!ready ? <p className="mb-3 text-sm text-muted">Loading…</p> : null}
      <Toolbar q={table.q} onSearch={(value) => { table.setQ(value); table.setPage(1) }} placeholder={`Search ${title.toLowerCase()}`} />
      <DataTable columns={['Name', 'About', 'Points']} empty={ready && table.total === 0 ? 'No one approved in this area yet.' : undefined}>
        {table.rows.map((person) => {
          const user = person.user
          return (
            <tr key={person.id} className="align-top">
              <td className="px-4 py-3">
                <p className="font-semibold">{user?.name}</p>
                <p className="text-muted">{roleLabel[user?.role ?? ''] ?? user?.role}</p>
              </td>
              <td className="px-4 py-3 text-muted">
                <p className="line-clamp-2">{person.bio}</p>
                <p className="mt-1">{[person.qualifications, person.experience].filter(Boolean).join(' · ')}</p>
              </td>
              <td className="px-4 py-3 font-semibold text-teal">{person.satisfaction_points}</td>
            </tr>
          )
        })}
      </DataTable>
      <Pager page={table.page} pages={table.pages} total={table.total} pageSize={table.pageSize} onPage={table.setPage} />
    </section>
  )
}
