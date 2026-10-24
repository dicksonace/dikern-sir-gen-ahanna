import { useState, type FormEvent } from 'react'
import { Link, Navigate, useNavigate } from 'react-router-dom'
import { ApiError } from '../api'
import { useAuth } from '../auth'

export function LoginPage() {
  const { user, ready, login } = useAuth()
  const navigate = useNavigate()
  const [email, setEmail] = useState('admin@sirgen.lk')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [submitting, setSubmitting] = useState(false)

  if (!ready) return <p className="p-8 text-muted">Loading…</p>
  if (user) return <Navigate to="/dashboard" replace />

  async function onSubmit(event: FormEvent) {
    event.preventDefault()
    setSubmitting(true)
    setError('')
    try {
      await login(email, password)
      navigate('/dashboard')
    } catch (caught) {
      setError(caught instanceof ApiError ? caught.message : 'Could not sign in.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <main className="grid min-h-screen bg-sand lg:grid-cols-2">
      <section className="hidden flex-col justify-between bg-deep p-12 text-white lg:flex">
        <div className="flex items-center gap-3">
          <img src={`${import.meta.env.BASE_URL}logo.png`} alt="" className="h-14 w-14 rounded-2xl" />
          <div>
            <p className="text-lg font-semibold">සර් ගෙන් අහන්න</p>
            <p className="text-sm text-white/65">Admin</p>
          </div>
        </div>
        <div className="max-w-md">
          <h1 className="text-4xl font-semibold leading-tight">Both sides, one desk.</h1>
          <p className="mt-4 text-white/75">Learning tracks and law practice areas are managed here. People still use the mobile app.</p>
        </div>
        <p className="text-sm text-white/50">Students, tutors, clients, and lawyers sign in on the phone.</p>
      </section>
      <section className="grid place-items-center px-4 py-16">
        <form onSubmit={onSubmit} className="w-full max-w-md rounded-3xl border border-line bg-white p-8">
          <img src={`${import.meta.env.BASE_URL}logo.png`} alt="" className="h-14 w-14 rounded-2xl lg:hidden" />
          <p className="mt-4 text-sm font-semibold text-teal lg:mt-0">සර් ගෙන් අහන්න</p>
          <h1 className="mt-1 text-3xl font-semibold">Admin sign in</h1>
          <p className="mt-2 text-sm text-muted">Use the website account. App passwords stay on the phone.</p>
          <label className="mt-6 block text-sm font-semibold" htmlFor="email">Email</label>
          <input
            id="email"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            className="mt-2 w-full rounded-xl border border-line px-3 py-3"
            required
          />
          <label className="mt-4 block text-sm font-semibold" htmlFor="password">Password</label>
          <input
            id="password"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            className="mt-2 w-full rounded-xl border border-line px-3 py-3"
            required
          />
          {error ? <p className="mt-3 rounded-xl bg-red-50 px-3 py-2 text-sm text-red-800">{error}</p> : null}
          <button
            type="submit"
            disabled={submitting}
            className="mt-6 w-full rounded-xl bg-teal px-4 py-3 font-semibold text-white disabled:opacity-60"
          >
            {submitting ? 'Signing in…' : 'Sign in'}
          </button>
          <Link to="/" className="mt-4 block text-center text-sm text-muted">Back</Link>
        </form>
      </section>
    </main>
  )
}
