import { useEffect, useState, type ReactNode } from 'react'
import { api, apiRoot, getToken } from '../api'
import { useAuth } from '../auth'
import { AdminShell } from '../components/AdminShell'

export function PageFrame({
  eyebrow,
  title,
  note,
  action,
  error,
  children,
}: {
  eyebrow: string
  title: string
  note: string
  action?: ReactNode
  error?: string
  children: ReactNode
}) {
  return (
    <AdminShell>
      <div className="mx-auto max-w-7xl">
        <div className="overflow-hidden rounded-3xl border border-line bg-white">
          <div className="h-2 bg-teal" />
          <div className="flex flex-wrap items-start justify-between gap-3 p-4 sm:p-6 md:p-8">
            <div className="min-w-0">
              <p className="text-sm font-semibold text-teal">{eyebrow}</p>
              <h1 className="mt-1 text-2xl font-semibold sm:text-3xl">{title}</h1>
              <p className="mt-2 max-w-2xl text-sm text-muted sm:text-base">{note}</p>
            </div>
            {action}
          </div>
        </div>
        {error ? <p className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-800">{error}</p> : null}
        <div className="mt-6">{children}</div>
      </div>
    </AdminShell>
  )
}

export function FilePreview({
  preview,
  onClose,
}: {
  preview: { url: string; type: string; title: string } | null
  onClose: () => void
}) {
  if (!preview) return null
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/60 p-4" onClick={onClose}>
      <div className="max-h-[90vh] w-full max-w-3xl overflow-auto rounded-3xl bg-white p-4" onClick={(event) => event.stopPropagation()}>
        <div className="mb-3 flex items-center justify-between gap-3">
          <p className="font-semibold">{preview.title}</p>
          <button type="button" onClick={onClose} className="rounded-xl border border-line px-3 py-2 text-sm font-semibold">
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
  )
}

export function useDeskLoad<T>(path: string, empty: T) {
  const { user } = useAuth()
  const [data, setData] = useState<T>(empty)
  const [error, setError] = useState('')

  async function load(silent = false) {
    if (!silent) setError('')
    try {
      setData(await api<T>(path))
    } catch (caught) {
      if (!silent) setError(caught instanceof Error ? caught.message : 'Could not load this page.')
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
  }, [user, path])

  return { data, error, setError, load }
}

export function useFilePreview() {
  const [preview, setPreview] = useState<{ url: string; type: string; title: string } | null>(null)
  const [error, setError] = useState('')

  function closePreview() {
    setPreview((current) => {
      if (current) URL.revokeObjectURL(current.url)
      return null
    })
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

  return { preview, error, setError, openPrivateFile, closePreview }
}
