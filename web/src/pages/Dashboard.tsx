import { Link } from 'react-router-dom'
import { type Overview } from '../api'
import { useAuth } from '../auth'
import { PageFrame, useDeskLoad } from './Desk'

export function DashboardPage() {
  const { user } = useAuth()
  const { data: overview, error } = useDeskLoad<Overview | null>('/admin/overview', null)
  const learning = overview?.learning
  const law = overview?.law

  return (
    <PageFrame
      eyebrow="Overview"
      title="Both sides"
      note={`Signed in as ${user?.email}. Learning tracks and law practice areas are managed here. People still use the mobile app.`}
      error={error}
    >
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Link to="/approvals" className="rounded-2xl bg-white px-4 py-3 no-underline">
          <Stat label="Waiting for approval" value={overview?.pending_profiles ?? '—'} />
        </Link>
        <Link to="/approvals" className="rounded-2xl bg-white px-4 py-3 no-underline">
          <Stat label="Identity documents" value={overview?.pending_kyc ?? '—'} />
        </Link>
        <Link to="/payments" className="rounded-2xl bg-white px-4 py-3 no-underline">
          <Stat label="Payments to check" value={overview?.pending_payments ?? '—'} />
        </Link>
        <Link to="/questions" className="rounded-2xl bg-white px-4 py-3 no-underline">
          <Stat label="Open questions" value={overview?.open_questions ?? '—'} />
        </Link>
      </div>

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
            <section className="rounded-3xl border border-line bg-white p-6">
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
    </PageFrame>
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

