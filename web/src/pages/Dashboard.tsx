import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api, apiRoot, getToken, type Overview, type TeacherProfile } from '../api'
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
  const [busyId, setBusyId] = useState<string | null>(null)
  const [kyc, setKyc] = useState<KycDocument[]>([])
  const [profiles, setProfiles] = useState<TeacherProfile[]>([])
  const [payments, setPayments] = useState<PaymentReview[]>([])
  const [questions, setQuestions] = useState<QuestionRow[]>([])
  const [lessons, setLessons] = useState<LessonRow[]>([])
  const [accounts, setAccounts] = useState<AccountRow[]>([])
  const [notes, setNotes] = useState<Record<number, string>>({})
  const [rowNote, setRowNote] = useState<Record<number, string>>({})
  const [preview, setPreview] = useState<{ url: string; type: string; title: string } | null>(null)

  function closePreview() {
    setPreview((current) => {
      if (current) URL.revokeObjectURL(current.url)
      return null
    })
  }

  async function load(silent = false) {
    if (!silent) setError('')
    try {
      const [nextOverview, nextKyc, nextProfiles, nextPayments, nextQuestions, nextLessons, nextAccounts] = await Promise.all([
        api<Overview>('/admin/overview'),
        api<KycDocument[]>('/admin/kyc'),
        api<TeacherProfile[]>('/admin/profiles'),
        api<PaymentReview[]>('/admin/pending-payments'),
        api<QuestionRow[]>('/admin/questions'),
        api<LessonRow[]>('/admin/lessons'),
        api<AccountRow[]>('/admin/accounts'),
      ])
      setOverview(nextOverview)
      setKyc(nextKyc)
      setProfiles(nextProfiles)
      setPayments(nextPayments)
      setQuestions(nextQuestions)
      setLessons(nextLessons)
      setAccounts(nextAccounts)
    } catch (caught) {
      if (!silent) {
        setError(caught instanceof Error ? caught.message : 'Could not load the dashboard.')
      }
    }
  }

  useEffect(() => {
    if (!user) return
    void load()
    const timer = window.setInterval(() => {
      if (document.visibilityState === 'visible') void load(true)
    }, 15000)
    const onVisible = () => {
      if (document.visibilityState === 'visible') void load(true)
    }
    document.addEventListener('visibilitychange', onVisible)
    return () => {
      window.clearInterval(timer)
      document.removeEventListener('visibilitychange', onVisible)
    }
  }, [user])

  async function approve(id: number) {
    setBusyId(`profile-${id}`)
    setRowNote((current) => ({ ...current, [id]: '' }))
    setError('')
    try {
      await api(`/admin/tutors/${id}/approve`, { method: 'POST' })
      await load()
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : 'Could not approve.'
      setRowNote((current) => ({ ...current, [id]: message }))
    } finally {
      setBusyId(null)
    }
  }

  async function openPrivateFile(path: string, title: string) {
    const token = getToken()
    const response = await fetch(`${apiRoot()}/api${path}`, {
      cache: 'no-store',
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    })
    if (!response.ok) {
      setError('Could not open that document.')
      return
    }
    const blob = await response.blob()
    setPreview((current) => {
      if (current) URL.revokeObjectURL(current.url)
      return { url: URL.createObjectURL(blob), type: blob.type, title }
    })
  }

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

  async function closeQuestion(id: number) {
    setBusyId(`question-${id}`)
    setError('')
    try {
      await api(`/admin/questions/${id}/close`, { method: 'POST' })
      await load()
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not close that question.')
    } finally {
      setBusyId(null)
    }
  }

  async function decideKyc(id: number, decision: 'approve' | 'reject') {
    if (decision === 'reject' && !(notes[id] ?? '').trim()) {
      setError('Write a short reason before asking them to upload again.')
      return
    }
    setBusyId(`kyc-${id}`)
    setError('')
    try {
      await api(`/admin/kyc/${id}/${decision}`, {
        method: 'POST',
        body: decision === 'reject' ? JSON.stringify({ note: notes[id] }) : undefined,
      })
      await load()
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not review that document.')
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
            <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <Stat label="Waiting for approval" value={overview?.pending_profiles ?? '—'} />
              <Stat label="Identity documents" value={overview?.pending_kyc ?? '—'} />
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

        <section id="profiles" className="mt-6 rounded-3xl border border-line bg-white p-6">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 className="text-xl font-semibold">Teacher profiles</h2>
              <p className="mt-1 max-w-2xl text-sm text-muted">
                Every tutor, lecturer, lawyer, and counsel, including people still waiting. The track pages only list people you have already approved. This list refreshes on its own.
              </p>
            </div>
            <button type="button" onClick={() => void load()} className="rounded-xl border border-line px-3 py-2 text-sm font-semibold">
              Refresh
            </button>
          </div>
          {profiles.length === 0 ? <p className="mt-4 text-sm text-muted">No teacher profiles yet.</p> : null}
          <ul className="mt-4 space-y-3">
            {profiles.map((profile) => {
              const person = profile.user
              const identity = person?.identity_document
              const initial = person?.name?.slice(0, 1).toUpperCase() || '?'
              const side = person?.division === 'law' ? 'Law advice' : 'Learning'
              const details = [profile.qualifications, profile.experience].filter(Boolean).join(' · ')
              return (
                <li key={profile.id} className="rounded-2xl border border-line p-4">
                  <div className="flex flex-wrap items-start gap-3">
                    <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-teal/10 text-lg font-semibold text-teal">
                      {initial}
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="font-semibold">{person?.name ?? 'Unknown'}</p>
                      <p className="text-sm text-muted">
                        {side} · {roleLabel[person?.role ?? ''] ?? person?.role}
                        {person?.phone ? ` · ${person.phone}` : ''}
                      </p>
                    </div>
                    <span className="rounded-full bg-sand px-3 py-1 text-xs font-semibold">{statusLabel[profile.status] ?? profile.status}</span>
                  </div>
                  <p className="mt-3 text-sm leading-6">{profile.bio?.trim() || 'No about text yet.'}</p>
                  {details ? <p className="mt-1 text-sm text-muted">{details}</p> : null}
                  {profile.subjects && profile.subjects.length > 0 ? (
                    <p className="mt-1 text-sm text-muted">{profile.subjects.map((subject) => subject.name).join(' · ')}</p>
                  ) : null}
                  <div className="mt-3 flex flex-wrap items-center gap-3">
                    <p className="text-sm text-muted">{identityLabel[identity?.status ?? ''] ?? 'No identity document yet.'}</p>
                    {identity ? (
                      <button
                        type="button"
                        onClick={() => void openPrivateFile(`/admin/kyc/${identity.id}/file`, person?.name ?? 'Identity document')}
                        className="rounded-xl border border-line px-3 py-2 text-sm font-semibold"
                      >
                        Open document
                      </button>
                    ) : null}
                  </div>
                  {identity?.status === 'rejected' && identity.note ? <p className="mt-2 text-sm text-muted">{identity.note}</p> : null}
                </li>
              )
            })}
          </ul>
        </section>

        <section id="identity" className="mt-6 rounded-3xl border border-line bg-white p-6">
          <h2 className="text-xl font-semibold">Identity documents</h2>
          <p className="mt-1 text-sm text-muted">People upload a NIC, passport, or driving licence. Approve it here before you approve their profile.</p>
          {kyc.length === 0 ? <p className="mt-4 text-sm text-muted">No documents are waiting.</p> : null}
          <ul className="mt-4 space-y-3">
            {kyc.map((document) => {
              const person = document.user
              const side = person?.division === 'law' ? 'Law advice' : 'Learning'
              return (
                <li key={document.id} className="rounded-2xl border border-line p-4">
                  <div className="flex flex-wrap items-center gap-3">
                    <div className="min-w-0 flex-1">
                      <p className="font-semibold">{person?.name ?? 'Unknown'}</p>
                      <p className="text-sm text-muted">
                        {side} · {roleLabel[person?.role ?? ''] ?? person?.role} · {kindLabel[document.kind] ?? document.kind}
                      </p>
                    </div>
                    <button type="button" onClick={() => void openPrivateFile(`/admin/kyc/${document.id}/file`, person?.name ?? 'Identity document')} className="rounded-xl border border-line px-3 py-2 text-sm font-semibold">
                      Open file
                    </button>
                    <button
                      type="button"
                      disabled={busyId === `kyc-${document.id}`}
                      onClick={() => void decideKyc(document.id, 'approve')}
                      className="rounded-xl bg-teal px-3 py-2 text-sm font-semibold text-white disabled:opacity-60"
                    >
                      Approve
                    </button>
                  </div>
                  <div className="mt-3 flex gap-2">
                    <input
                      value={notes[document.id] ?? ''}
                      onChange={(event) => setNotes((current) => ({ ...current, [document.id]: event.target.value }))}
                      placeholder="Reason, if you need a clearer copy"
                      className="min-w-0 flex-1 rounded-xl border border-line px-3 py-2 text-sm"
                    />
                    <button
                      type="button"
                      disabled={busyId === `kyc-${document.id}`}
                      onClick={() => void decideKyc(document.id, 'reject')}
                      className="rounded-xl border border-line px-3 py-2 text-sm font-semibold"
                    >
                      Ask again
                    </button>
                  </div>
                </li>
              )
            })}
          </ul>
        </section>

        <section id="payments" className="mt-6 rounded-3xl border border-line bg-white p-6">
          <h2 className="text-xl font-semibold">Payments to check</h2>
          <p className="mt-1 text-sm text-muted">Bank slips sent from the app. Open the slip, then mark the payment as received.</p>
          {payments.length === 0 ? <p className="mt-4 text-sm text-muted">No payments are waiting.</p> : null}
          <ul className="mt-4 space-y-3">
            {payments.map((payment) => {
              const person = payment.student
              const packageName = payment.subscription?.package?.name ?? 'Package'
              const tutorName = payment.subscription?.tutor?.name ?? 'Teacher'
              const amount = Math.round(Number(payment.amount)).toLocaleString()
              return (
                <li key={payment.id} className="rounded-2xl border border-line p-4">
                  <div className="flex flex-wrap items-center gap-3">
                    <div className="min-w-0 flex-1">
                      <p className="font-semibold">{person?.name ?? 'Unknown'} · Rs {amount}</p>
                      <p className="text-sm text-muted">{packageName} · {tutorName}</p>
                    </div>
                    {payment.has_slip ? (
                      <button
                        type="button"
                        onClick={() => void openPrivateFile(`/admin/payments/${payment.id}/file`, `${person?.name ?? 'Payment'} slip`)}
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
        </section>

        <section id="questions" className="mt-6 rounded-3xl border border-line bg-white p-6">
          <h2 className="text-xl font-semibold">Questions</h2>
          <p className="mt-1 text-sm text-muted">What students and clients sent, including a photo or file. Closing a question does not answer it.</p>
          {questions.length === 0 ? <p className="mt-4 text-sm text-muted">No questions yet.</p> : null}
          <ul className="mt-4 space-y-3">
            {questions.map((question) => (
              <li key={question.id} className="rounded-2xl border border-line p-4">
                <div className="flex flex-wrap items-start gap-3">
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold">{question.student?.name ?? 'Unknown'} → {question.tutor?.name ?? 'Teacher'}</p>
                    <p className="text-sm text-muted">
                      {question.student?.division === 'law' ? 'Law advice' : 'Learning'}
                      {question.subject?.name ? ` · ${question.subject.name}` : ''}
                      {' · '}
                      {question.status === 'closed' ? 'Closed' : question.status === 'answered' ? 'Answered' : 'Open'}
                    </p>
                  </div>
                  {question.has_attachment ? (
                    <button
                      type="button"
                      onClick={() => void openPrivateFile(`/admin/questions/${question.id}/file`, `${question.student?.name ?? 'Question'} file`)}
                      className="rounded-xl border border-line px-3 py-2 text-sm font-semibold"
                    >
                      Open file
                    </button>
                  ) : null}
                  {question.status !== 'closed' ? (
                    <button
                      type="button"
                      disabled={busyId === `question-${question.id}`}
                      onClick={() => void closeQuestion(question.id)}
                      className="rounded-xl border border-line px-3 py-2 text-sm font-semibold disabled:opacity-60"
                    >
                      {busyId === `question-${question.id}` ? 'Closing…' : 'Close'}
                    </button>
                  ) : null}
                </div>
                <p className="mt-3 text-sm leading-6">{question.body?.trim() || 'No written question. The file is the message.'}</p>
                {question.replies && question.replies.length > 0 ? (
                  <ul className="mt-3 space-y-2">
                    {question.replies.map((reply) => (
                      <li key={reply.id} className="rounded-xl bg-sand px-3 py-2 text-sm">
                        <p className="font-semibold">{reply.tutor?.name ?? 'Reply'}</p>
                        <p className="mt-1 leading-6">{reply.content}</p>
                        {reply.has_attachment ? (
                          <button
                            type="button"
                            onClick={() => void openPrivateFile(`/admin/questions/${question.id}/replies/${reply.id}/file`, 'Reply file')}
                            className="mt-2 rounded-lg border border-line bg-white px-3 py-1.5 text-sm font-semibold"
                          >
                            Open reply file
                          </button>
                        ) : null}
                      </li>
                    ))}
                  </ul>
                ) : null}
              </li>
            ))}
          </ul>
        </section>

        <section id="lessons" className="mt-6 rounded-3xl border border-line bg-white p-6">
          <h2 className="text-xl font-semibold">Lessons</h2>
          <p className="mt-1 text-sm text-muted">Booked lessons and consultations.</p>
          {lessons.length === 0 ? <p className="mt-4 text-sm text-muted">No lessons yet.</p> : null}
          <ul className="mt-4 space-y-3">
            {lessons.map((lesson) => (
              <li key={lesson.id} className="rounded-2xl border border-line p-4">
                <div className="flex flex-wrap items-center gap-3">
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold">{lesson.title}</p>
                    <p className="text-sm text-muted">
                      {lesson.student?.name ?? 'Student'} · {lesson.tutor?.name ?? 'Teacher'}
                      {lesson.scheduled_at ? ` · ${new Date(lesson.scheduled_at).toLocaleString()}` : ''}
                    </p>
                  </div>
                  <span className="rounded-full bg-sand px-3 py-1 text-xs font-semibold capitalize">{lesson.status}</span>
                </div>
              </li>
            ))}
          </ul>
        </section>

        <section id="accounts" className="mt-6 rounded-3xl border border-line bg-white p-6">
          <h2 className="text-xl font-semibold">Students and clients</h2>
          <p className="mt-1 text-sm text-muted">People who learn or ask for advice. Teachers stay in Profiles.</p>
          {accounts.length === 0 ? <p className="mt-4 text-sm text-muted">No student or client accounts yet.</p> : null}
          <ul className="mt-4 space-y-3">
            {accounts.map((account) => (
              <li key={account.id} className="flex flex-wrap items-center gap-3 rounded-2xl border border-line p-4">
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
        </section>

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
              const identity = person?.identity_document?.status
              const identityReady = identity === 'approved'
              const identityNote = identityReady
                ? ''
                : identity === 'pending'
                  ? 'Their identity document is in the list above. Approve that document first, then approve this profile.'
                  : identity === 'rejected'
                    ? 'Their last identity document was not accepted. They need to upload another one before this profile can be approved.'
                    : 'They have not uploaded an identity document yet. The profile can be approved after that document is approved.'
              return (
                <li key={profile.id} className="rounded-2xl border border-line p-4">
                  <div className="flex items-center gap-3">
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
                      disabled={!identityReady || busyId === `profile-${profile.id}`}
                      onClick={() => void approve(profile.id)}
                      className="ml-auto rounded-xl bg-teal px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
                    >
                      {busyId === `profile-${profile.id}` ? 'Approving…' : identityReady ? 'Approve' : 'Needs identity first'}
                    </button>
                  </div>
                  {identityNote ? <p className="mt-3 text-sm text-muted">{identityNote}</p> : null}
                  {rowNote[profile.id] ? <p className="mt-3 text-sm font-semibold text-red-800">{rowNote[profile.id]}</p> : null}
                </li>
              )
            })}
          </ul>
        </section>
      </div>
      {preview ? (
        <div className="fixed inset-0 z-50 grid place-items-center bg-black/60 p-4" onClick={() => closePreview()}>
          <div className="max-h-[90vh] w-full max-w-3xl overflow-auto rounded-3xl bg-white p-4" onClick={(event) => event.stopPropagation()}>
            <div className="mb-3 flex items-center justify-between gap-3">
              <p className="font-semibold">{preview.title}</p>
              <button type="button" onClick={() => closePreview()} className="rounded-xl border border-line px-3 py-2 text-sm font-semibold">
                Close
              </button>
            </div>
            {preview.type.startsWith('image/') ? (
              <img src={preview.url} alt="" className="max-h-[70vh] w-full object-contain" />
            ) : preview.type.startsWith('video/') ? (
              <video src={preview.url} controls className="max-h-[70vh] w-full" />
            ) : (
              <iframe title={preview.title} src={preview.url} className="h-[70vh] w-full rounded-2xl border border-line" />
            )}
          </div>
        </div>
      ) : null}
    </AdminShell>
  )
}

type QuestionRow = {
  id: number
  body: string | null
  status: string
  has_attachment: boolean
  student?: { name: string; role: string; division: string } | null
  tutor?: { name: string; role: string } | null
  subject?: { name: string } | null
  replies?: Array<{
    id: number
    content: string | null
    has_attachment: boolean
    tutor?: { name: string } | null
  }>
}

type LessonRow = {
  id: number
  title: string
  scheduled_at: string | null
  status: string
  student?: { name: string } | null
  tutor?: { name: string } | null
}

type AccountRow = {
  id: number
  name: string
  email: string
  phone: string | null
  role: string
  division: string
}

type PaymentReview = {
  id: number
  amount: string
  has_slip: boolean
  student?: { name: string; email: string } | null
  subscription?: {
    package?: { name: string } | null
    tutor?: { name: string } | null
  } | null
}

type KycDocument = {
  id: number
  kind: string
  status: string
  user?: {
    name: string
    email: string
    role: string
    division: string
  }
}

const kindLabel: Record<string, string> = {
  nic: 'NIC',
  passport: 'Passport',
  driving_licence: 'Driving licence',
}

const statusLabel: Record<string, string> = {
  pending: 'Waiting for approval',
  approved: 'Approved',
  rejected: 'Not approved',
}

const identityLabel: Record<string, string> = {
  pending: 'Identity document is waiting for a check.',
  approved: 'Identity document is approved.',
  rejected: 'Identity document needs another copy.',
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
