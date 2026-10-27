import { Fragment, useState } from 'react'
import { api, type QuestionRow } from '../api'
import { Badge, DataTable, FilterPills, Pager, StatCard, statusTone, Toolbar, useTable } from '../ui'
import { FilePreview, PageFrame, useDeskLoad, useFilePreview } from './Desk'

function matchQuestion(row: QuestionRow, q: string) {
  return `${row.body ?? ''} ${row.status} ${row.student?.name ?? ''} ${row.tutor?.name ?? ''} ${row.subject?.name ?? ''}`.toLowerCase().includes(q)
}

export function QuestionsPage() {
  const { data: questions, error, setError, load } = useDeskLoad<QuestionRow[]>('/admin/questions', [])
  const files = useFilePreview()
  const [busyId, setBusyId] = useState<string | null>(null)
  const [openId, setOpenId] = useState<number | null>(null)
  const [status, setStatus] = useState('all')
  const filtered = questions.filter((row) => (status === 'all' ? true : row.status === status))
  const table = useTable(filtered, matchQuestion)

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

  return (
    <PageFrame
      eyebrow="Messages"
      title="Questions"
      note="What students and clients sent, including a photo or file. Closing a thread does not answer it."
      error={error || files.error}
    >
      <div className="mb-6 grid gap-3 sm:grid-cols-4">
        <StatCard label="Open" value={questions.filter((row) => row.status === 'open').length} />
        <StatCard label="Answered" value={questions.filter((row) => row.status === 'answered').length} />
        <StatCard label="Closed" value={questions.filter((row) => row.status === 'closed').length} />
        <StatCard label="With files" value={questions.filter((row) => row.has_attachment).length} />
      </div>
      <Toolbar q={table.q} onSearch={(value) => { table.setQ(value); table.setPage(1) }} placeholder="Search question, student, or teacher">
        <FilterPills
          value={status}
          onChange={(id) => { setStatus(id); table.setPage(1) }}
          options={[
            { id: 'all', label: 'All' },
            { id: 'open', label: 'Open' },
            { id: 'answered', label: 'Answered' },
            { id: 'closed', label: 'Closed' },
          ]}
        />
      </Toolbar>
      <DataTable columns={['From', 'Subject', 'Question', 'Status', '']} empty={table.total === 0 ? 'No questions match.' : undefined}>
        {table.rows.map((question) => (
          <Fragment key={question.id}>
            <tr>
              <td className="px-4 py-3">
                <p className="font-semibold">{question.student?.name ?? 'Unknown'}</p>
                <p className="text-muted">
                  {question.student?.division === 'law' ? 'Law' : 'Learning'} → {question.tutor?.name ?? 'Teacher'}
                </p>
              </td>
              <td className="px-4 py-3 text-muted">{question.subject?.name ?? '—'}</td>
              <td className="max-w-sm px-4 py-3">
                <p className="line-clamp-2">{question.body?.trim() || 'File only'}</p>
              </td>
              <td className="px-4 py-3">
                <Badge tone={statusTone(question.status)}>{question.status}</Badge>
              </td>
              <td className="px-4 py-3 text-right">
                <div className="flex justify-end gap-2">
                  {question.has_attachment ? (
                    <button type="button" onClick={() => void files.openPrivateFile(`/admin/questions/${question.id}/file`, `${question.student?.name ?? 'Question'} file`)} className="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold">
                      File
                    </button>
                  ) : null}
                  <button type="button" onClick={() => setOpenId(openId === question.id ? null : question.id)} className="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold">
                    {openId === question.id ? 'Hide' : 'Thread'}
                  </button>
                  {question.status !== 'closed' ? (
                    <button type="button" disabled={busyId === `question-${question.id}`} onClick={() => void closeQuestion(question.id)} className="rounded-lg border border-line px-3 py-1.5 text-xs font-semibold disabled:opacity-60">
                      Close
                    </button>
                  ) : null}
                </div>
              </td>
            </tr>
            {openId === question.id ? (
              <tr>
                <td colSpan={5} className="bg-sand/60 px-4 py-3">
                  <p className="text-sm leading-6">{question.body?.trim() || 'No written question. The file is the message.'}</p>
                  {question.replies && question.replies.length > 0 ? (
                    <ul className="mt-3 space-y-2">
                      {question.replies.map((reply) => (
                        <li key={reply.id} className="rounded-xl bg-white px-3 py-2 text-sm">
                          <p className="font-semibold">{reply.tutor?.name ?? 'Reply'}</p>
                          <p className="mt-1 leading-6">{reply.content}</p>
                          {reply.has_attachment ? (
                            <button type="button" onClick={() => void files.openPrivateFile(`/admin/questions/${question.id}/replies/${reply.id}/file`, 'Reply file')} className="mt-2 rounded-lg border border-line px-3 py-1.5 text-xs font-semibold">
                              Open reply file
                            </button>
                          ) : null}
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className="mt-2 text-sm text-muted">No replies yet.</p>
                  )}
                </td>
              </tr>
            ) : null}
          </Fragment>
        ))}
      </DataTable>
      <Pager page={table.page} pages={table.pages} total={table.total} pageSize={table.pageSize} onPage={table.setPage} />
      <FilePreview preview={files.preview} onClose={files.closePreview} />
    </PageFrame>
  )
}
