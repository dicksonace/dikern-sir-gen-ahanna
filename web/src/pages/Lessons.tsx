import { type LessonRow } from '../api'
import { PageFrame, useDeskLoad } from './Desk'

export function LessonsPage() {
  const { data: lessons, error } = useDeskLoad<LessonRow[]>('/admin/lessons', [])

  return (
    <PageFrame eyebrow="Diary" title="Lessons" note="Booked lessons and consultations." error={error}>
      {lessons.length === 0 ? <p className="text-sm text-muted">No lessons yet.</p> : null}
      <ul className="space-y-3">
        {lessons.map((lesson) => (
          <li key={lesson.id} className="rounded-3xl border border-line bg-white p-4">
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
    </PageFrame>
  )
}
