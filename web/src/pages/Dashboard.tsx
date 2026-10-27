import { useState } from 'react'
import { Link } from 'react-router-dom'
import { roleLabel, type Overview } from '../api'
import { useAuth } from '../auth'
import { Badge, FilterPills, StatCard, statusTone } from '../ui'
import { PageFrame, useDeskLoad } from './Desk'

export function DashboardPage() {
  const { user } = useAuth()
  const [side, setSide] = useState('all')
  const [range, setRange] = useState('all')
  const { data: overview, error } = useDeskLoad<Overview | null>(`/admin/overview?side=${side}&range=${range}`, null)
  const totals = overview?.totals
  const learning = overview?.learning
  const law = overview?.law

  return (
    <PageFrame
      eyebrow="Overview"
      title="Both sides"
      note={`Signed in as ${user?.name ?? user?.email}. Filter the desk by side and by how recent the activity is.`}
      error={error}
    >
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-center sm:justify-between">
        <FilterPills
          value={side}
          onChange={setSide}
          options={[
            { id: 'all', label: 'All' },
            { id: 'learning', label: 'Learning' },
            { id: 'law', label: 'Law' },
          ]}
        />
        <FilterPills
          value={range}
          onChange={setRange}
          options={[
            { id: 'all', label: 'All time' },
            { id: '30', label: '30 days' },
            { id: '7', label: '7 days' },
          ]}
        />
      </div>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <Link to="/approvals" className="no-underline">
          <StatCard label="Waiting for approval" value={overview?.pending_profiles ?? '—'} />
        </Link>
        <Link to="/approvals" className="no-underline">
          <StatCard label="Identity documents" value={overview?.pending_kyc ?? '—'} />
        </Link>
        <Link to="/payments" className="no-underline">
          <StatCard label="Payments waiting" value={overview?.pending_payments ?? '—'} hint={money(totals?.payments_waiting_rs)} />
        </Link>
        <Link to="/questions" className="no-underline">
          <StatCard label="Open questions" value={overview?.open_questions ?? '—'} />
        </Link>
        <StatCard label="People on this filter" value={totals?.people ?? '—'} hint={`${totals?.new_people ?? 0} new in range`} />
        <StatCard label="Approved teachers" value={totals?.approved_teachers ?? '—'} />
        <StatCard label="Active packages" value={totals?.active_subscriptions ?? '—'} hint={`${totals?.waiting_subscriptions ?? 0} waiting`} />
        <StatCard label="Received in range" value={money(totals?.payments_received_rs)} />
        <StatCard label="Lessons" value={totals?.lessons ?? '—'} />
        <StatCard label="Questions" value={totals?.questions ?? '—'} />
        <StatCard label="Commission waiting" value={money(totals?.commission_waiting_rs)} />
        <Link to="/mail" className="no-underline">
          <StatCard label="Mail waiting" value={totals?.mail_waiting ?? '—'} hint={`${totals?.mail_failed ?? 0} failed`} />
        </Link>
      </div>

      <div className="mt-6 grid gap-3 sm:grid-cols-3">
        <StatCard label="Students" value={learning?.students ?? '—'} />
        <StatCard label="Tutors" value={learning?.tutors ?? '—'} />
        <StatCard label="Lecturers" value={learning?.lecturers ?? '—'} />
        <StatCard label="Clients" value={law?.clients ?? '—'} />
        <StatCard label="Lawyers" value={law?.lawyers ?? '—'} />
        <StatCard label="Legal counsel" value={law?.counsel ?? '—'} />
      </div>

      <div className="mt-6 grid items-start gap-6 xl:grid-cols-[minmax(0,1.4fr)_minmax(0,20rem)]">
        <div className="min-w-0 space-y-6">
          {(overview?.charts.tracks ?? []).map((track) => (
            <section key={track.slug} className="rounded-3xl border border-line bg-white p-4 sm:p-6">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-teal">Learning</p>
                  <h2 className="mt-1 text-xl font-semibold sm:text-2xl">{track.name}</h2>
                  <p className="mt-1 text-sm text-muted">
                    {track.kind === 'programme' ? 'One programme.' : 'Teal is people teaching. Amber is questions asked.'}
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
          {(overview?.charts.law_areas ?? []).length > 0 ? (
            <section className="rounded-3xl border border-line bg-white p-4 sm:p-6">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-teal">Law advice</p>
                  <h2 className="mt-1 text-xl font-semibold sm:text-2xl">Practice areas</h2>
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
          ) : null}

          <section className="rounded-3xl border border-line bg-white p-4 sm:p-6">
            <h2 className="text-lg font-semibold">Latest accounts</h2>
            <ul className="mt-3 divide-y divide-line">
              {(overview?.recent?.people ?? []).map((person) => (
                <li key={person.id} className="flex flex-wrap items-center gap-2 py-3 text-sm">
                  <span className="min-w-0 flex-1 font-semibold">{person.name}</span>
                  <Badge>{roleLabel[person.role] ?? person.role}</Badge>
                  <span className="text-muted">{person.division === 'law' ? 'Law' : 'Learning'}</span>
                </li>
              ))}
              {(overview?.recent?.people ?? []).length === 0 ? <li className="py-3 text-sm text-muted">No new accounts on this filter.</li> : null}
            </ul>
          </section>

          <section className="rounded-3xl border border-line bg-white p-4 sm:p-6">
            <div className="flex items-center justify-between gap-3">
              <h2 className="text-lg font-semibold">Latest questions</h2>
              <Link to="/questions" className="text-sm font-semibold text-teal">Open</Link>
            </div>
            <ul className="mt-3 divide-y divide-line">
              {(overview?.recent?.questions ?? []).map((question) => (
                <li key={question.id} className="py-3">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="min-w-0 flex-1 text-sm font-semibold">{question.student?.name} → {question.tutor?.name}</p>
                    <Badge tone={statusTone(question.status)}>{question.status}</Badge>
                  </div>
                  <p className="mt-1 line-clamp-2 text-sm text-muted">{question.body}</p>
                </li>
              ))}
            </ul>
          </section>
        </div>
        <div className="min-w-0 space-y-6">
          <section className="rounded-3xl border border-line bg-white p-4 sm:p-6">
            <h2 className="text-lg font-semibold">People</h2>
            <p className="mt-1 text-sm text-muted">{learning?.students ?? 0} learning accounts · {law?.clients ?? 0} clients</p>
            <PeopleChart rows={overview?.charts.people ?? []} />
          </section>
          <StatusCard title="Questions" rows={overview?.charts.questions ?? []} />
          <StatusCard title="Lessons" rows={overview?.charts.lessons ?? []} />
          <StatusCard
            title="Payments"
            rows={(overview?.charts.payments ?? []).map((row) => ({
              label: `${row.label} · ${money(row.amount)}`,
              value: row.value,
            }))}
          />
          <section className="rounded-3xl border border-line bg-white p-4 sm:p-6">
            <div className="flex items-center justify-between gap-3">
              <h2 className="text-lg font-semibold">Latest payments</h2>
              <Link to="/payments" className="text-sm font-semibold text-teal">Open</Link>
            </div>
            <ul className="mt-3 space-y-3 text-sm">
              {(overview?.recent?.payments ?? []).map((payment) => (
                <li key={payment.id} className="rounded-2xl bg-sand px-3 py-2">
                  <p className="font-semibold">{payment.student?.name} · {money(Number(payment.amount))}</p>
                  <p className="text-muted">{payment.status}</p>
                </li>
              ))}
            </ul>
          </section>
        </div>
      </div>
    </PageFrame>
  )
}

function money(value?: number) {
  return `Rs ${Math.round(Number(value ?? 0)).toLocaleString()}`
}

function ColumnChart({ rows }: { rows: Array<{ name: string; slug: string; tutors: number; questions: number }> }) {
  const max = Math.max(1, ...rows.flatMap((row) => [row.tutors, row.questions]))
  if (rows.length === 0) return <p className="mt-6 text-sm text-muted">Nothing to chart yet.</p>
  return (
    <div className="min-w-0">
      <div className="mt-6 flex gap-4 text-xs font-semibold text-muted">
        <span className="inline-flex items-center gap-2"><i className="h-2.5 w-2.5 rounded-sm bg-teal" /> Teaching</span>
        <span className="inline-flex items-center gap-2"><i className="h-2.5 w-2.5 rounded-sm bg-amber-400" /> Questions</span>
      </div>
      <div className="mt-4 flex items-end gap-2 overflow-x-auto">
        {rows.map((row) => (
          <div key={row.slug} className="flex min-w-[3.5rem] flex-1 flex-col items-center">
            <div className="flex h-36 items-end gap-1 sm:h-44">
              <div className="w-3 rounded-t-md bg-teal sm:w-3.5" style={{ height: `${Math.max(row.tutors ? 8 : 0, (row.tutors / max) * 100)}%` }} title={`${row.tutors} teaching`} />
              <div className="w-3 rounded-t-md bg-amber-400 sm:w-3.5" style={{ height: `${Math.max(row.questions ? 8 : 0, (row.questions / max) * 100)}%` }} title={`${row.questions} questions`} />
            </div>
            <p className="mt-2 text-center text-[11px] font-semibold leading-4 sm:text-xs">{row.name}</p>
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
        className="mx-auto grid h-36 w-36 place-items-center rounded-full sm:h-40 sm:w-40"
        style={{ background: total === 0 ? '#e3e8ea' : `conic-gradient(${stops.join(', ')})` }}
      >
        <div className="grid h-22 w-22 place-items-center rounded-full bg-white text-center sm:h-24 sm:w-24" style={{ height: 88, width: 88 }}>
          <span>
            <b className="block text-2xl">{total}</b>
            <span className="text-xs text-muted">people</span>
          </span>
        </div>
      </div>
      <ul className="mt-4 space-y-2">
        {rows.map((row, index) => (
          <li key={row.label} className="flex items-center gap-2 text-sm">
            <i className="h-2.5 w-2.5 shrink-0 rounded-sm" style={{ background: colors[index % colors.length] }} />
            <span className="min-w-0 flex-1 truncate">{row.label}</span>
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
    <section className="rounded-3xl border border-line bg-white p-4 sm:p-6">
      <h2 className="text-lg font-semibold">{title}</h2>
      {rows.length === 0 ? <p className="mt-3 text-sm text-muted">No records yet.</p> : (
        <ul className="mt-4 space-y-3">
          {rows.map((row) => (
            <li key={row.label}>
              <div className="flex justify-between gap-3 text-sm">
                <span className="min-w-0 truncate capitalize">{row.label}</span>
                <span className="shrink-0 font-semibold">{row.value}</span>
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
