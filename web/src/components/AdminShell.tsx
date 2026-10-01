import { useEffect, useState, type ReactNode } from 'react'
import { Link, NavLink, Navigate, useLocation } from 'react-router-dom'
import { api } from '../api'
import { useAuth } from '../auth'

type Item = { to: string; label: string }

const learningFallback: Item[] = [
  { to: '/learning/a-l', label: 'For A/L' },
  { to: '/learning/o-l', label: 'For O/L' },
  { to: '/learning/grade-5-scholarship', label: 'Grade 5 scholarship' },
]

const lawFallback: Item[] = [
  { to: '/law/family-law', label: 'Family law' },
  { to: '/law/property', label: 'Property' },
  { to: '/law/employment', label: 'Employment' },
  { to: '/law/business', label: 'Business' },
]

export function AdminShell({ children }: { children: ReactNode }) {
  const { user, ready, logout } = useAuth()
  const { pathname, hash } = useLocation()
  const [learning, setLearning] = useState<Item[]>(learningFallback)
  const [law, setLaw] = useState<Item[]>(lawFallback)

  useEffect(() => {
    if (!user) return
    function loadNav() {
      void api<Array<{ name: string; slug: string }>>('/tracks?division=tutor')
        .then((rows) => {
          if (rows.length > 0) {
            setLearning(rows.map((row) => ({ to: `/learning/${row.slug}`, label: row.name })))
          }
        })
        .catch(() => setLearning(learningFallback))
      void api<Array<{ name: string; slug: string }>>('/subjects?division=law')
        .then((rows) => {
          if (rows.length > 0) {
            setLaw(rows.map((row) => ({ to: `/law/${row.slug}`, label: row.name })))
          }
        })
        .catch(() => setLaw(lawFallback))
    }
    loadNav()
    window.addEventListener('admin-nav-refresh', loadNav)
    return () => window.removeEventListener('admin-nav-refresh', loadNav)
  }, [user])

  if (!ready) return <p className="p-8 text-muted">Loading…</p>
  if (!user) return <Navigate to="/login" replace />

  return (
    <div className="grid min-h-screen grid-cols-[272px_1fr] bg-sand">
      <aside className="sticky top-0 flex h-screen flex-col overflow-y-auto bg-deep px-4 py-5 text-white">
        <div className="flex items-center gap-3 px-2">
          <img src="/logo.png" alt="" className="h-12 w-12 rounded-2xl object-cover" />
          <div className="min-w-0">
            <p className="truncate text-base font-semibold leading-tight">සර් ගෙන් අහන්න</p>
            <p className="mt-0.5 text-xs tracking-wide text-white/60">Admin</p>
          </div>
        </div>
        <nav className="mt-6 flex flex-1 flex-col gap-1 text-sm">
          <Link
            to="/dashboard"
            aria-current={pathname === '/dashboard' && hash !== '#waiting' ? 'page' : undefined}
            className={linkClass({ isActive: pathname === '/dashboard' && hash !== '#waiting' })}
          >
            Overview
          </Link>
          <NavGroup label="Learning" base="/learning" items={learning} />
          <NavGroup label="Law advice" base="/law" items={law} />
          <Link
            to="/dashboard#waiting"
            aria-current={pathname === '/dashboard' && hash === '#waiting' ? 'page' : undefined}
            className={linkClass({ isActive: pathname === '/dashboard' && hash === '#waiting' })}
          >
            Approvals
          </Link>
        </nav>
        <div className="mt-6 rounded-2xl bg-white/10 p-3">
          <p className="truncate text-xs text-white/70">{user.email}</p>
          <button
            type="button"
            onClick={() => void logout()}
            className="mt-3 w-full rounded-lg bg-white px-3 py-2 text-sm font-semibold text-deep"
          >
            Log out
          </button>
        </div>
      </aside>
      <main className="min-w-0 px-6 py-8">{children}</main>
    </div>
  )
}

function NavGroup({ label, base, items }: { label: string; base: string; items: Item[] }) {
  const { pathname } = useLocation()
  const sectionActive = pathname.startsWith(base)
  const [open, setOpen] = useState(sectionActive)

  useEffect(() => {
    if (sectionActive) setOpen(true)
  }, [sectionActive])

  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen((value) => !value)}
        className={`flex w-full items-center justify-between rounded-lg px-3 py-2 text-left ${sectionActive ? 'bg-white/10' : 'text-white/80'}`}
        aria-expanded={open}
      >
        <span>{label}</span>
        <span className={`text-xs text-white/60 ${open ? 'rotate-90' : ''}`}>›</span>
      </button>
      {open ? (
        <div className="mt-1 ml-3 border-l border-white/15 pl-2">
          {items.map((item) => (
            <NavLink key={item.to} to={item.to} className={subLinkClass}>
              {item.label}
            </NavLink>
          ))}
        </div>
      ) : null}
    </div>
  )
}

function linkClass({ isActive }: { isActive: boolean }) {
  return isActive
    ? 'block rounded-lg bg-white/15 px-3 py-2 font-semibold'
    : 'block rounded-lg px-3 py-2 text-white/80'
}

function subLinkClass({ isActive }: { isActive: boolean }) {
  return isActive
    ? 'block rounded-lg bg-white/15 px-3 py-2'
    : 'block rounded-lg px-3 py-2 text-white/70'
}
