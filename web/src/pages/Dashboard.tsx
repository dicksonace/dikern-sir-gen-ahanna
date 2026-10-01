import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api, type Overview } from '../api'
import { useAuth } from '../auth'
import { AdminShell } from '../components/AdminShell'

const roleLabel: Record<string, string> = {
  student: 'Student',
  tutor: 'Tutor',
  lecturer: 'Lecturer',
  client: 'Client',
  lawyer: 'Lawyer',
  counsel: 'Legal counsel',
}

export function DashboardPage() {
  const { user } = useAuth()
  const [overview, setOverview] = useState<Overview | null>(null)
  const [error, setError] = useState('')
  const [busyId, setBusyId] = useState<number | null>(null)

  async function load() {
    setError('')
    try {
      setOverview(await api<Overview>('/admin/overview'))
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not load the dashboard.')
    }
  }

  useEffect(() => {
    if (user) {
      void load()
    }
  }, [user])

  async function approve(id: number) {
    setBusyId(id)
    try {
      await api(`/admin/tutors/${id}/approve`, { method: 'POST' })
      await load()
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not approve.')
    } finally {
      setBusyId(null)
    }
  }

  const learning = overview?.learning
  const law = overview?.law

  return (
    <AdminShell>
      <div className="mx-auto max-w-6xl">
        <div className="overflow-hidden rounded-3xl border border-line bg-white">
          <div className="h-2 bg-teal" />
          <div className="p-6 md:p-8">
            <p id="overview" className="text-sm font-semibold text-teal">Overview</p>
            <h1 className="mt-1 text-3xl font-semibold">Both sides</h1>
            <p className="mt-2 max-w-2xl text-muted">
              Signed in as {user?.email}. Learning tracks and law practice areas are managed here. People still use the mobile app.
            </p>
            <div className="mt-6 grid gap-3 sm:grid-cols-3">
              <Stat label="Waiting for approval" value={overview?.pending_profiles ?? '—'} />
              <Stat label="Payments to check" value={overview?.pending_payments ?? '—'} />
              <Stat label="Open questions" value={overview?.open_questions ?? '—'} />
            </div>
          </div>
        </div>

        {error ? <p className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-800">{error}</p> : null}

        <div className="mt-6 grid items-start gap-6 xl:grid-cols-[minmax(0,1.4fr)_320px]">
          <div className="space-y-6">
            {(overview?.charts.tracks ?? []).map((track) => (
              <section key={track.slug} id={track.slug === 'a-l' ? 'learning' : undefined} className="rounded-3xl border border-line bg-white p-6">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="text-sm font-semibold text-teal">Learning</p>
                    <h2 className="mt-1 text-2xl font-semibold">{track.name}</h2>
                    <p className="mt-1 text-sm text-muted">
                      {track.kind === 'programme'
                        ? 'One programme. It is not drawn as a list of subjects.'
                        : 'Teal is people teaching. Amber is questions asked.'}
                    </p>
                  </div>
                  <Link to={`/learning/${track.slug}`} className="shrink-0 rounded-xl bg-teal px-3 py-2 text-sm font-semibold text-white">
                    Open
                  </Link>
                </div>
                {track.kind === 'programme' ? (
                  <p className="mt-6 rounded-2xl bg-sand px-4 py-6 text-sm text-muted">Grade 5 scholarship stays one programme, so there is no subject chart.</p>
                ) : (
                  <ColumnChart rows={track.subjects} />
                )}
              </section>
            ))}
            <section id="law" className="rounded-3xl border border-line bg-white p-6">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-sm font-semibold text-teal">Law advice</p>
                  <h2 className="mt-1 text-2xl font-semibold">Practice areas</h2>
                  <p className="mt-1 text-sm text-muted">Teal is approved lawyers and counsel. Amber is questions.</p>
                </div>
                <Link to="/law/family-law" className="shrink-0 rounded-xl bg-teal px-3 py-2 text-sm font-semibold text-white">
                  Open
                </Link>
              </div>
              <ColumnChart
                rows={(overview?.charts.law_areas ?? []).map((area) => ({
                  name: area.name,
                  slug: area.slug,
                  tutors: area.people,
                  questions: area.questions,
                }))}
              />
            </section>
          </div>
          <div className="space-y-6">
            <section className="rounded-3xl border border-line bg-white p-6">
              <h2 className="text-lg font-semibold">People</h2>
              <p className="mt-1 text-sm text-muted">{learning?.students ?? 0} learning accounts · {law?.clients ?? 0} clients</p>
              <PeopleChart rows={overview?.charts.people ?? []} />
            </section>
            <StatusCard title="Questions" rows={overview?.charts.questions ?? []} />
            <StatusCard title="Lessons" rows={overview?.charts.lessons ?? []} />
            <StatusCard
              title="Payments"
              rows={(overview?.charts.payments ?? []).map((row) => ({
                label: `${row.label} · Rs ${Math.round(row.amount).toLocaleString()}`,
                value: row.value,
              }))}
            />
          </div>
        </div>

        <section id="waiting" className="mt-6 rounded-3xl border border-line bg-white p-6">
          <h2 className="text-xl font-semibold">Waiting for approval</h2>
          <p className="mt-1 text-sm text-muted">Tutors, lecturers, lawyers, and counsel appear here until you approve them.</p>
          {!overview ? <p className="mt-4 text-sm text-muted">Loading people…</p> : null}
          {overview && overview.pending.length === 0 ? (
            <p className="mt-4 text-sm text-muted">No one is waiting.</p>
          ) : null}
          <ul className="mt-4 space-y-3">
            {overview?.pending.map((profile) => {
              const person = profile.user
              const initial = person?.name?.slice(0, 1).toUpperCase() || '?'
              const side = person?.division === 'law' ? 'Law advice' : 'Learning'
              return (
                <li key={profile.id} className="flex items-center gap-3 rounded-2xl border border-line p-4">
                  <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-teal/10 text-lg font-semibold text-teal">
                    {initial}
                  </span>
                  <div className="min-w-0">
                    <p className="font-semibold">{person?.name ?? 'Unknown'}</p>
                    <p className="text-sm text-muted">
                      {side} · {roleLabel[person?.role ?? ''] ?? person?.role}
                    </p>
                  </div>
                  <button
                    type="button"
                    disabled={busyId === profile.id}
                    onClick={() => void approve(profile.id)}
                    className="ml-auto rounded-xl bg-teal px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
                  >
                    {busyId === profile.id ? 'Approving…' : 'Approve'}
                  </button>
                </li>
              )
            })}
          </ul>
        </section>
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

function ColumnChart({ rows }: { rows: Array<{ name: string; slug: string; tutors: number; questions: number }> }) {
  const max = Math.max(1, ...rows.flatMap((row) => [row.tutors, row.questions]))
  if (rows.length === 0) return <p className="mt-6 text-sm text-muted">Nothing to chart yet.</p>
  return (
    <div>
      <div className="mt-6 flex gap-4 text-xs font-semibold text-muted">
        <span className="inline-flex items-center gap-2"><i className="h-2.5 w-2.5 rounded-sm bg-teal" /> Teaching</span>
        <span className="inline-flex items-center gap-2"><i className="h-2.5 w-2.5 rounded-sm bg-amber-400" /> Questions</span>
      </div>
      <div className="mt-4 flex items-end gap-2 overflow-x-auto">
        {rows.map((row) => (
          <div key={row.slug} className="flex min-w-[4.5rem] flex-1 flex-col items-center">
            <div className="flex h-44 items-end gap-1">
              <div className="w-3.5 rounded-t-md bg-teal" style={{ height: `${Math.max(row.tutors ? 8 : 0, (row.tutors / max) * 100)}%` }} title={`${row.tutors} teaching`} />
              <div className="w-3.5 rounded-t-md bg-amber-400" style={{ height: `${Math.max(row.questions ? 8 : 0, (row.questions / max) * 100)}%` }} title={`${row.questions} questions`} />
            </div>
            <p className="mt-2 text-center text-xs font-semibold leading-4">{row.name}</p>
            <p className="text-center text-[11px] text-muted">{row.tutors} · {row.questions}</p>
          </div>
        ))}
      </div>
    </div>
  )
}

function PeopleChart({ rows }: { rows: Array<{ label: string; value: number; side: 'learning' | 'law' }> }) {
  const total = rows.reduce((sum, row) => sum + row.value, 0)
  const colors = ['#0D7377', '#14919B', '#1B4965', '#E2A93B', '#E07A5F', '#2A9D8F']
  let cursor = 0
  const stops = rows.map((row, index) => {
    const start = total === 0 ? 0 : (cursor / total) * 100
    cursor += row.value
    const end = total === 0 ? 0 : (cursor / total) * 100
    return `${colors[index % colors.length]} ${start}% ${end}%`
  })
  return (
    <div className="mt-5">
      <div
        className="mx-auto grid h-40 w-40 place-items-center rounded-full"
        style={{ background: total === 0 ? '#e3e8ea' : `conic-gradient(${stops.join(', ')})` }}
      >
        <div className="grid h-24 w-24 place-items-center rounded-full bg-white text-center">
          <span>
            <b className="block text-2xl">{total}</b>
            <span className="text-xs text-muted">people</span>
          </span>
        </div>
      </div>
      <ul className="mt-4 space-y-2">
        {rows.map((row, index) => (
          <li key={row.label} className="flex items-center gap-2 text-sm">
            <i className="h-2.5 w-2.5 rounded-sm" style={{ background: colors[index % colors.length] }} />
            <span className="flex-1">{row.label}</span>
            <span className="font-semibold">{row.value}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}

function StatusCard({ title, rows }: { title: string; rows: Array<{ label: string; value: number }> }) {
  const max = Math.max(1, ...rows.map((row) => row.value))
  return (
    <section className="rounded-3xl border border-line bg-white p-6">
      <h2 className="text-lg font-semibold">{title}</h2>
      {rows.length === 0 ? <p className="mt-3 text-sm text-muted">No records yet.</p> : (
        <ul className="mt-4 space-y-3">
          {rows.map((row) => (
            <li key={row.label}>
              <div className="flex justify-between text-sm">
                <span className="capitalize">{row.label}</span>
                <span className="font-semibold">{row.value}</span>
              </div>
              <div className="mt-1 h-2 rounded-full bg-sand">
                <div className="h-2 rounded-full bg-teal" style={{ width: `${(row.value / max) * 100}%` }} />
              </div>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}
