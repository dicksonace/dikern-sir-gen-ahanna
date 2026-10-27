import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { useAuth } from '../auth'
import { PageFrame } from './Desk'

export function AccountPage() {
  const { user, refresh } = useAuth()
  const [name, setName] = useState(user?.name ?? '')
  const [phone, setPhone] = useState(user?.phone ?? '')
  const [current, setCurrent] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [error, setError] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState('')

  async function saveProfile(event: FormEvent) {
    event.preventDefault()
    setBusy('profile')
    setError('')
    setNote('')
    try {
      await api('/profile', { method: 'PUT', body: JSON.stringify({ name, phone }) })
      await refresh()
      setNote('Profile saved.')
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not save your profile.')
    } finally {
      setBusy('')
    }
  }

  async function savePassword(event: FormEvent) {
    event.preventDefault()
    setBusy('password')
    setError('')
    setNote('')
    try {
      await api('/change-password', {
        method: 'POST',
        body: JSON.stringify({ current_password: current, password, password_confirmation: confirm }),
      })
      setCurrent('')
      setPassword('')
      setConfirm('')
      setNote('Password changed. A confirmation email is queued.')
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not change the password.')
    } finally {
      setBusy('')
    }
  }

  return (
    <PageFrame
      eyebrow="You"
      title="My profile"
      note="Your name, phone, and password for this admin website. App users keep their own profile on the phone."
      error={error}
    >
      {note ? <p className="mb-4 rounded-xl bg-teal/10 px-4 py-3 text-sm text-teal">{note}</p> : null}
      <div className="grid gap-6 lg:grid-cols-2">
        <form onSubmit={(event) => void saveProfile(event)} className="rounded-3xl border border-line bg-white p-5">
          <h2 className="text-lg font-semibold">Details</h2>
          <label className="mt-4 block text-sm font-semibold" htmlFor="staff-name">Name</label>
          <input id="staff-name" value={name} onChange={(event) => setName(event.target.value)} className="mt-2 w-full rounded-xl border border-line px-3 py-3" required />
          <label className="mt-4 block text-sm font-semibold" htmlFor="staff-phone">Phone</label>
          <input id="staff-phone" value={phone} onChange={(event) => setPhone(event.target.value)} className="mt-2 w-full rounded-xl border border-line px-3 py-3" />
          <p className="mt-3 text-sm text-muted">{user?.email}</p>
          <button type="submit" disabled={busy === 'profile'} className="mt-5 w-full rounded-xl bg-teal px-4 py-3 font-semibold text-white disabled:opacity-60">
            {busy === 'profile' ? 'Saving…' : 'Save profile'}
          </button>
        </form>
        <form onSubmit={(event) => void savePassword(event)} className="rounded-3xl border border-line bg-white p-5">
          <h2 className="text-lg font-semibold">Password</h2>
          <label className="mt-4 block text-sm font-semibold" htmlFor="current-password">Current password</label>
          <input id="current-password" type="password" value={current} onChange={(event) => setCurrent(event.target.value)} className="mt-2 w-full rounded-xl border border-line px-3 py-3" required />
          <label className="mt-4 block text-sm font-semibold" htmlFor="new-password">New password</label>
          <input id="new-password" type="password" value={password} onChange={(event) => setPassword(event.target.value)} minLength={6} className="mt-2 w-full rounded-xl border border-line px-3 py-3" required />
          <label className="mt-4 block text-sm font-semibold" htmlFor="confirm-password">Confirm</label>
          <input id="confirm-password" type="password" value={confirm} onChange={(event) => setConfirm(event.target.value)} minLength={6} className="mt-2 w-full rounded-xl border border-line px-3 py-3" required />
          <button type="submit" disabled={busy === 'password'} className="mt-5 w-full rounded-xl border border-teal px-4 py-3 font-semibold text-teal disabled:opacity-60">
            {busy === 'password' ? 'Saving…' : 'Change password'}
          </button>
        </form>
      </div>
    </PageFrame>
  )
}
