import { useState } from 'react'
import { type LessonRow } from '../api'
import { Badge, DataTable, FilterPills, Pager, StatCard, statusTone, Toolbar, useTable } from '../ui'
import { PageFrame, useDeskLoad } from './Desk'

function matchLesson(row: LessonRow, q: string) {
  return `${row.title} ${row.status} ${row.student?.name ?? ''} ${row.tutor?.name ?? ''}`.toLowerCase().includes(q)
}

export function LessonsPage() {
  const { data: lessons, error } = useDeskLoad<LessonRow[]>('/admin/lessons', [])
  const [status, setStatus] = useState('all')
  const filtered = lessons.filter((row) => (status === 'all' ? true : row.status === status))
  const table = useTable(filtered, matchLesson)

  return (
    <PageFrame eyebrow="Diary" title="Lessons" note="Booked lessons and consultations." error={error}>
      <div className="mb-6 grid gap-3 sm:grid-cols-4">
        <StatCard label="All" value={lessons.length} />
        <StatCard label="Scheduled" value={lessons.filter((row) => row.status === 'scheduled').length} />
        <StatCard label="Live" value={lessons.filter((row) => row.status === 'live').length} />
        <StatCard label="Completed" value={lessons.filter((row) => row.status === 'completed').length} />
      </div>
      <Toolbar q={table.q} onSearch={(value) => { table.setQ(value); table.setPage(1) }} placeholder="Search lesson, student, or teacher">
        <FilterPills
          value={status}
          onChange={(id) => { setStatus(id); table.setPage(1) }}
          options={[
            { id: 'all', label: 'All' },
            { id: 'scheduled', label: 'Scheduled' },
            { id: 'live', label: 'Live' },
            { id: 'completed', label: 'Completed' },
            { id: 'cancelled', label: 'Cancelled' },
          ]}
        />
      </Toolbar>
      <DataTable columns={['Lesson', 'People', 'When', 'Length', 'Status']} empty={table.total === 0 ? 'No lessons match.' : undefined}>
        {table.rows.map((lesson) => (
          <tr key={lesson.id}>
            <td className="px-4 py-3 font-semibold">{lesson.title}</td>
            <td className="px-4 py-3 text-muted">
              {lesson.student?.name ?? 'Student'} · {lesson.tutor?.name ?? 'Teacher'}
            </td>
            <td className="px-4 py-3 text-muted">{lesson.scheduled_at ? new Date(lesson.scheduled_at).toLocaleString() : '—'}</td>
            <td className="px-4 py-3 tabular-nums">{lesson.duration_minutes ? `${lesson.duration_minutes} min` : '—'}</td>
            <td className="px-4 py-3">
              <Badge tone={statusTone(lesson.status)}>{lesson.status}</Badge>
            </td>
          </tr>
        ))}
      </DataTable>
      <Pager page={table.page} pages={table.pages} total={table.total} pageSize={table.pageSize} onPage={table.setPage} />
    </PageFrame>
  )
}
