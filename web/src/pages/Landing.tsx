import { Link, Navigate } from 'react-router-dom'
import { useAuth } from '../auth'

export function LandingPage() {
  const { user, ready } = useAuth()
  if (!ready) return <p className="p-8 text-muted">Loading…</p>
  if (user) return <Navigate to="/dashboard" replace />

  return (
    <main className="min-h-screen bg-sand text-ink">
      <div className="mx-auto grid min-h-screen max-w-6xl items-center gap-10 px-6 py-16 lg:grid-cols-[1.1fr_0.9fr]">
        <div>
          <img src={`${import.meta.env.BASE_URL}logo.png`} alt="" className="h-16 w-16 rounded-2xl" />
          <p className="mt-6 text-sm font-semibold text-teal">Admin website</p>
          <h1 className="mt-2 text-5xl font-semibold leading-tight">සර් ගෙන් අහන්න</h1>
          <p className="mt-4 max-w-xl text-lg text-muted">
            Run both sides of the app from here. Students, tutors, clients, and lawyers stay on the phone.
          </p>
          <Link
            to="/login"
            className="mt-8 inline-flex rounded-xl bg-teal px-5 py-3 font-semibold text-white"
          >
            Admin sign in
          </Link>
        </div>
        <div className="space-y-4">
          <section className="rounded-3xl border border-line bg-white p-6">
            <p className="text-sm font-semibold text-teal">Learning</p>
            <h2 className="mt-1 text-2xl font-semibold">For A/L, O/L, and Grade 5</h2>
            <p className="mt-2 text-muted">Students, tutors, and lecturers. A/L and O/L hold subjects. Grade 5 scholarship is one programme.</p>
          </section>
          <section className="rounded-3xl border border-line bg-white p-6">
            <p className="text-sm font-semibold text-teal">Law advice</p>
            <h2 className="mt-1 text-2xl font-semibold">Practice areas</h2>
            <p className="mt-2 text-muted">Clients, lawyers, and legal counsel. Family law, property, employment, and business stay off the exam tracks.</p>
          </section>
        </div>
      </div>
    </main>
  )
}
