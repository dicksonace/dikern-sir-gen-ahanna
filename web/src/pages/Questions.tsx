import { useState } from 'react'
import { api, type QuestionRow } from '../api'
import { FilePreview, PageFrame, useDeskLoad, useFilePreview } from './Desk'

export function QuestionsPage() {
  const { data: questions, error, setError, load } = useDeskLoad<QuestionRow[]>('/admin/questions', [])
  const files = useFilePreview()
  const [busyId, setBusyId] = useState<string | null>(null)

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
      note="What students and clients sent, including a photo or file. Closing a question does not answer it."
      error={error || files.error}
    >
      {questions.length === 0 ? <p className="text-sm text-muted">No questions yet.</p> : null}
      <ul className="space-y-3">
        {questions.map((question) => (
          <li key={question.id} className="rounded-3xl border border-line bg-white p-4">
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
                  onClick={() => void files.openPrivateFile(`/admin/questions/${question.id}/file`, `${question.student?.name ?? 'Question'} file`)}
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
                        onClick={() => void files.openPrivateFile(`/admin/questions/${question.id}/replies/${reply.id}/file`, 'Reply file')}
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
      <FilePreview preview={files.preview} onClose={files.closePreview} />
    </PageFrame>
  )
}
