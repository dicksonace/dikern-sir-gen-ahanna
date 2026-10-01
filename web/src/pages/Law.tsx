import { useEffect, useState, type FormEvent } from 'react'
import { useParams } from 'react-router-dom'
import { api, ApiError } from '../api'
import { AdminShell } from '../components/AdminShell'

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
      <div className="mx-auto max-w-6xl">
        <div className="overflow-hidden rounded-3xl border border-line bg-white">
          <div className="h-2" style={{ background: accent }} />
          <div className="p-6 md:p-8">
            <p className="text-sm font-semibold text-teal">Law advice</p>
            <h1 className="mt-1 text-3xl font-semibold">{area?.name ?? 'Practice area'}</h1>
            <p className="mt-2 max-w-2xl text-muted">
              Clients book a lawyer or legal counsel in this area. It is not an exam track.
            </p>
            <div className="mt-6 grid gap-3 sm:grid-cols-3">
              <Stat label="Lawyers" value={area ? lawyers.length : '—'} />
              <Stat label="Legal counsel" value={area ? counsel.length : '—'} />
              <Stat label="Packages" value={packages.length || '—'} />
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

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-2xl bg-sand px-4 py-3">
      <p className="text-2xl font-semibold">{value}</p>
      <p className="text-sm text-muted">{label}</p>
    </div>
  )
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
  return (
    <section className="rounded-3xl border border-line bg-white p-5">
      <h2 className="text-lg font-semibold">{title}</h2>
      <p className="mt-1 text-sm text-muted">{hint}</p>
      {!ready ? <p className="mt-4 text-sm text-muted">Loading…</p> : null}
      {ready && people.length === 0 ? <p className="mt-4 text-sm text-muted">No one approved in this area yet.</p> : null}
      <ul className="mt-4 space-y-3">
        {people.map((person) => {
          const user = person.user
          const initial = user?.name?.slice(0, 1).toUpperCase() || '?'
          const slots = person.available_slots ?? []
          return (
            <li key={person.id} className="rounded-2xl border border-line p-4">
              <div className="flex items-start gap-3">
                <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-teal/10 text-lg font-semibold text-teal">
                  {initial}
                </span>
                <div className="min-w-0">
                  <p className="font-semibold">{user?.name}</p>
                  <p className="text-sm text-muted">{roleLabel[user?.role ?? ''] ?? user?.role}</p>
                </div>
                <p className="ml-auto text-sm font-semibold text-teal">{person.satisfaction_points} pts</p>
              </div>
              {person.bio ? <p className="mt-3 text-sm leading-6 text-ink">{person.bio}</p> : null}
              <p className="mt-2 text-sm text-muted">
                {[person.qualifications, person.experience].filter(Boolean).join(' · ')}
              </p>
              {slots.length > 0 ? (
                <div className="mt-3 flex flex-wrap gap-2">
                  {slots.map((slot) => (
                    <span key={slot} className="rounded-full bg-sand px-3 py-1 text-xs font-semibold">
                      {slot}
                    </span>
                  ))}
                </div>
              ) : null}
            </li>
          )
        })}
      </ul>
    </section>
  )
}
