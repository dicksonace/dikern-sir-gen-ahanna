import { useEffect, useState, type ReactNode } from 'react'
import { NavLink, Navigate, useLocation } from 'react-router-dom'
import { api, canOpen, pageForPath, pathForPage } from '../api'
import { useAuth } from '../auth'
import { Icon, icons } from '../ui'

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
  const location = useLocation()
  const [learning, setLearning] = useState<Item[]>(learningFallback)
  const [law, setLaw] = useState<Item[]>(lawFallback)
  const [open, setOpen] = useState(false)

  useEffect(() => {
    setOpen(false)
  }, [location.pathname])

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

  if (!ready) return <p className="p-6 text-muted">Loading…</p>
  if (!user) return <Navigate to="/login" replace />

  const page = pageForPath(location.pathname)
  if (!canOpen(user, page)) {
    return <Navigate to={pathForPage(canOpen(user, 'dashboard') ? 'dashboard' : 'account')} replace />
  }

  const nav = (
    <>
      <div className="flex items-center gap-3 px-2">
        <img src={`${import.meta.env.BASE_URL}logo.png`} alt="" className="h-11 w-11 rounded-2xl object-cover" />
        <div className="min-w-0">
          <p className="truncate text-base font-semibold leading-tight">සර් ගෙන් අහන්න</p>
          <p className="mt-0.5 text-xs tracking-wide text-white/60">Admin</p>
        </div>
      </div>
      <nav className="mt-6 flex flex-1 flex-col gap-1 overflow-y-auto text-sm">
        {canOpen(user, 'dashboard') ? (
          <NavItem to="/dashboard" icon={icons.overview} end>
            Overview
          </NavItem>
        ) : null}
        {canOpen(user, 'catalog') ? (
          <NavItem to="/catalog" icon={icons.catalog}>
            Catalog
          </NavItem>
        ) : null}
        {canOpen(user, 'learning') ? <NavGroup label="Learning" icon={icons.learning} base="/learning" items={learning} /> : null}
        {canOpen(user, 'law') ? <NavGroup label="Law advice" icon={icons.law} base="/law" items={law} /> : null}
        {canOpen(user, 'profiles') ? (
          <NavItem to="/profiles" icon={icons.profiles}>
            Profiles
          </NavItem>
        ) : null}
        {canOpen(user, 'questions') ? (
          <NavItem to="/questions" icon={icons.questions}>
            Questions
          </NavItem>
        ) : null}
        {canOpen(user, 'lessons') ? (
          <NavItem to="/lessons" icon={icons.lessons}>
            Lessons
          </NavItem>
        ) : null}
        {canOpen(user, 'students') ? (
          <NavItem to="/students" icon={icons.students}>
            Students
          </NavItem>
        ) : null}
        {canOpen(user, 'payments') ? (
          <NavItem to="/payments" icon={icons.payments}>
            Payments
          </NavItem>
        ) : null}
        {canOpen(user, 'approvals') ? (
          <NavItem to="/approvals" icon={icons.approvals}>
            Approvals
          </NavItem>
        ) : null}
        {canOpen(user, 'mail') ? (
          <NavItem to="/mail" icon={icons.mail}>
            Mail queue
          </NavItem>
        ) : null}
        {canOpen(user, 'staff') ? (
          <NavItem to="/staff" icon={icons.staff}>
            Staff
          </NavItem>
        ) : null}
        <NavItem to="/account" icon={icons.account}>
          My profile
        </NavItem>
      </nav>
      <div className="mt-4 rounded-2xl bg-white/10 p-3">
        <p className="truncate text-xs font-semibold">{user.name}</p>
        <p className="truncate text-xs text-white/70">{user.email}</p>
        <button
          type="button"
          onClick={() => void logout()}
          className="mt-3 w-full rounded-lg bg-white px-3 py-2 text-sm font-semibold text-deep"
        >
          Log out
        </button>
      </div>
    </>
  )

  return (
    <div className="flex h-dvh overflow-hidden bg-sand">
      {open ? (
        <button type="button" aria-label="Close menu" className="fixed inset-0 z-30 bg-black/40 md:hidden" onClick={() => setOpen(false)} />
      ) : null}
      <aside
        className={`fixed inset-y-0 left-0 z-40 flex w-[min(18rem,86vw)] flex-col overflow-hidden bg-deep px-4 py-5 text-white transition-transform duration-200 ease-out md:static md:w-72 md:translate-x-0 ${open ? 'translate-x-0' : '-translate-x-full md:translate-x-0'}`}
      >
        {nav}
      </aside>
      <div className="flex min-w-0 flex-1 flex-col overflow-hidden">
        <header className="flex shrink-0 items-center gap-3 border-b border-line bg-sand px-4 py-3 md:hidden">
          <button type="button" onClick={() => setOpen(true)} className="rounded-xl border border-line bg-white p-2" aria-label="Open menu">
            <Icon d={icons.menu} className="h-5 w-5" />
          </button>
          <p className="min-w-0 truncate font-semibold">සර් ගෙන් අහන්න</p>
        </header>
        <main className="min-w-0 flex-1 overflow-x-hidden overflow-y-auto overscroll-y-contain px-4 py-5 sm:px-6 sm:py-8">{children}</main>
      </div>
    </div>
  )
}

function NavItem({ to, icon, children, end }: { to: string; icon: string; children: ReactNode; end?: boolean }) {
  return (
    <NavLink to={to} end={end} className={subLinkClass}>
      <Icon d={icon} />
      <span className="min-w-0 truncate">{children}</span>
    </NavLink>
  )
}

function NavGroup({ label, icon, base, items }: { label: string; icon: string; base: string; items: Item[] }) {
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
        className={`flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-left ${sectionActive ? 'bg-white/10' : 'text-white/80'}`}
        aria-expanded={open}
      >
        <Icon d={icon} />
        <span className="min-w-0 flex-1 truncate">{label}</span>
        <span className={`text-xs text-white/60 ${open ? 'rotate-90' : ''}`}>›</span>
      </button>
      {open ? (
        <div className="mt-1 ml-8 border-l border-white/15 pl-2">
          {items.map((item) => (
            <NavLink key={item.to} to={item.to} className={subLinkClass}>
              <span className="min-w-0 truncate">{item.label}</span>
            </NavLink>
          ))}
        </div>
      ) : null}
    </div>
  )
}

function subLinkClass({ isActive }: { isActive: boolean }) {
  return isActive
    ? 'flex items-center gap-2.5 rounded-lg bg-white/15 px-3 py-2'
    : 'flex items-center gap-2.5 rounded-lg px-3 py-2 text-white/70'
}
