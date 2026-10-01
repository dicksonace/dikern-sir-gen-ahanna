import { useEffect, useState, type FormEvent } from 'react'
import { useParams } from 'react-router-dom'
import { api, ApiError } from '../api'
import { AdminShell } from '../components/AdminShell'

type SubjectRow = { id: number; name: string; slug: string }
type Track = {
  id: number
  name: string
  slug: string
  kind: 'subjects' | 'programme'
  description: string | null
  is_active: boolean
  subjects: SubjectRow[]
}
type Tutor = {
  id: number
  bio: string | null
  qualifications: string | null
  experience: string | null
  satisfaction_points: number
  user: { name: string; role: string } | null
  subjects: SubjectRow[]
}

const roleLabel: Record<string, string> = {
  tutor: 'Tutor',
  lecturer: 'Lecturer',
}

const accent: Record<string, string> = {
  'a-l': '#0D7377',
  'o-l': '#14919B',
  'grade-5-scholarship': '#1B4965',
}

export function LearningPage() {
  const { slug } = useParams()
  const [tracks, setTracks] = useState<Track[]>([])
  const [tutors, setTutors] = useState<Tutor[]>([])
  const [selectedId, setSelectedId] = useState<number | null>(null)
  const [subjectName, setSubjectName] = useState('')
  const [trackName, setTrackName] = useState('')
  const [description, setDescription] = useState('')
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  const selected = tracks.find((track) => track.id === selectedId) ?? null
  const subjectSlugs = new Set(selected?.subjects.map((subject) => subject.slug) ?? [])
  const teaching = selected?.kind === 'subjects'
    ? tutors.filter((tutor) => tutor.subjects.some((subject) => subjectSlugs.has(subject.slug)))
    : []
  const tutorCount = teaching.filter((tutor) => tutor.user?.role !== 'lecturer').length
  const lecturerCount = teaching.filter((tutor) => tutor.user?.role === 'lecturer').length

  async function load(keepId?: number) {
    const [rows, people] = await Promise.all([
      api<Track[]>('/admin/tracks'),
      api<Tutor[]>('/tutors?division=tutor'),
    ])
    setTracks(rows)
    setTutors(people)
    const current = rows.find((track) => track.id === (keepId ?? rows[0]?.id)) ?? rows[0]
    setSelectedId(current?.id ?? null)
    setTrackName(current?.name ?? '')
    setDescription(current?.description ?? '')
  }

  useEffect(() => {
    void load().catch((caught: unknown) => {
      setError(caught instanceof Error ? caught.message : 'Could not load tracks.')
    })
  }, [])

  useEffect(() => {
    const current = tracks.find((track) => track.slug === slug)
    if (!current) return
    setSelectedId(current.id)
    setTrackName(current.name)
    setDescription(current.description ?? '')
  }, [slug, tracks])

  async function saveTrack(extra?: { description?: string }) {
    if (!selected) return
    setSaving(true)
    setError('')
    try {
      await api(`/admin/tracks/${selected.id}`, {
        method: 'PUT',
        body: JSON.stringify({
          name: trackName,
          ...(extra?.description !== undefined ? { description: extra.description } : {}),
        }),
      })
      window.dispatchEvent(new Event('admin-nav-refresh'))
      await load(selected.id)
    } catch (caught) {
      setError(messageFrom(caught))
    } finally {
      setSaving(false)
    }
  }

  async function addSubject(event: FormEvent) {
    event.preventDefault()
    if (!selected) return
    setSaving(true)
    setError('')
    try {
      await api(`/admin/tracks/${selected.id}/subjects`, {
        method: 'POST',
        body: JSON.stringify({ name: subjectName }),
      })
      setSubjectName('')
      await load(selected.id)
    } catch (caught) {
      setError(messageFrom(caught))
    } finally {
      setSaving(false)
    }
  }

  return (
    <AdminShell>
      <div className="mx-auto max-w-6xl">
        <div className="overflow-hidden rounded-3xl border border-line bg-white">
          <div className="h-2" style={{ background: accent[selected?.slug ?? ''] ?? '#0D7377' }} />
          <div className="p-6 md:p-8">
            <p className="text-sm font-semibold text-teal">Learning</p>
            <h1 className="mt-1 text-3xl font-semibold">{selected?.name ?? 'Learning tracks'}</h1>
            <p className="mt-2 max-w-2xl text-muted">
              {selected?.kind === 'programme'
                ? 'One scholarship programme. Subjects such as Chemistry stay on For A/L.'
                : 'Students pick this track in the app. Tutors and lecturers are listed by the subjects they teach.'}
            </p>
            <div className="mt-6 grid gap-3 sm:grid-cols-3">
              <Stat label={selected?.kind === 'programme' ? 'Programme' : 'Subjects'} value={selected?.kind === 'programme' ? 1 : selected?.subjects.length ?? '—'} />
              <Stat label="Tutors" value={selected ? tutorCount : '—'} />
              <Stat label="Lecturers" value={selected ? lecturerCount : '—'} />
            </div>
          </div>
        </div>

        {error ? <p className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-800">{error}</p> : null}

        <div className="mt-6 grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
          <div className="space-y-6">
            {selected?.kind === 'subjects' ? (
              <section className="rounded-3xl border border-line bg-white p-5">
                <h2 className="text-lg font-semibold">Subjects</h2>
                <p className="mt-1 text-sm text-muted">These are the choices inside {selected.name}.</p>
                {selected.subjects.length === 0 ? <p className="mt-4 text-sm text-muted">No subjects yet.</p> : (
                  <ul className="mt-4 grid gap-3 sm:grid-cols-2">
                    {selected.subjects.map((subject) => (
                      <li key={subject.id} className="rounded-2xl bg-sand px-4 py-3">
                        <p className="font-semibold">{subject.name}</p>
                      </li>
                    ))}
                  </ul>
                )}
              </section>
            ) : null}

            {selected?.kind === 'programme' ? (
              <section className="rounded-3xl border border-line bg-white p-5">
                <h2 className="text-lg font-semibold">Programme</h2>
                <p className="mt-3 text-sm leading-6 text-ink">{selected.description || 'Add a short description students will read.'}</p>
              </section>
            ) : null}

            <section className="rounded-3xl border border-line bg-white p-5">
              <h2 className="text-lg font-semibold">{selected?.kind === 'programme' ? 'People' : 'Who teaches this'}</h2>
              <p className="mt-1 text-sm text-muted">
                {selected?.kind === 'programme'
                  ? 'Grade 5 is not split into A/L subjects, so tutors are not matched here.'
                  : 'Approved tutors and lecturers whose subjects sit on this track.'}
              </p>
              {selected?.kind === 'subjects' && teaching.length === 0 ? (
                <p className="mt-4 text-sm text-muted">No one approved for these subjects yet.</p>
              ) : null}
              <ul className="mt-4 space-y-3">
                {teaching.map((tutor) => {
                  const initial = tutor.user?.name?.slice(0, 1).toUpperCase() || '?'
                  return (
                    <li key={tutor.id} className="rounded-2xl border border-line p-4">
                      <div className="flex items-start gap-3">
                        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-teal/10 text-lg font-semibold text-teal">
                          {initial}
                        </span>
                        <div className="min-w-0">
                          <p className="font-semibold">{tutor.user?.name}</p>
                          <p className="text-sm text-muted">{roleLabel[tutor.user?.role ?? ''] ?? tutor.user?.role}</p>
                        </div>
                        <p className="ml-auto text-sm font-semibold text-teal">{tutor.satisfaction_points} pts</p>
                      </div>
                      {tutor.bio ? <p className="mt-3 text-sm leading-6">{tutor.bio}</p> : null}
                      <p className="mt-2 text-sm text-muted">{[tutor.qualifications, tutor.experience].filter(Boolean).join(' · ')}</p>
                      <p className="mt-2 text-sm text-muted">{tutor.subjects.map((subject) => subject.name).join(' · ')}</p>
                    </li>
                  )
                })}
              </ul>
            </section>
          </div>

          <section className="rounded-3xl border border-line bg-white p-5">
            <h2 className="text-lg font-semibold">{selected?.kind === 'programme' ? 'Edit programme' : 'Add a subject'}</h2>
            <p className="mt-1 text-sm text-muted">
              {selected?.kind === 'programme'
                ? 'The name and the note students read. Keep this as one programme.'
                : 'The name in the menu, plus a new subject for this track.'}
            </p>
            <form
              onSubmit={(event) => {
                event.preventDefault()
                if (selected?.kind === 'programme') {
                  void saveTrack({ description })
                  return
                }
                void saveTrack()
              }}
              className="mt-4 space-y-3"
            >
              <label className="block text-sm font-semibold" htmlFor="track-name">Track name</label>
              <input
                id="track-name"
                value={trackName}
                onChange={(event) => setTrackName(event.target.value)}
                className="w-full rounded-xl border border-line px-3 py-3"
                required
              />
              {selected?.kind === 'programme' ? (
                <textarea
                  value={description}
                  onChange={(event) => setDescription(event.target.value)}
                  rows={5}
                  className="w-full rounded-xl border border-line px-3 py-3"
                />
              ) : null}
              <button type="submit" disabled={saving || !selected} className="w-full rounded-xl bg-teal px-4 py-3 font-semibold text-white disabled:opacity-60">
                {saving ? 'Saving…' : 'Save'}
              </button>
            </form>
            {selected?.kind === 'subjects' ? (
              <form onSubmit={(event) => void addSubject(event)} className="mt-6 space-y-3 border-t border-line pt-5">
                <label className="block text-sm font-semibold" htmlFor="subject-name">New subject</label>
                <input
                  id="subject-name"
                  value={subjectName}
                  onChange={(event) => setSubjectName(event.target.value)}
                  placeholder="For example Physics"
                  className="w-full rounded-xl border border-line px-3 py-3"
                  required
                />
                <button type="submit" disabled={saving} className="w-full rounded-xl border border-teal px-4 py-3 font-semibold text-teal disabled:opacity-60">
                  Add subject
                </button>
              </form>
            ) : null}
          </section>
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

function messageFrom(caught: unknown) {
  return caught instanceof ApiError ? caught.message : 'Could not save.'
}
