import { useEffect, useMemo, useState, type ReactNode, type SVGProps } from 'react'

export function Icon({ d, ...props }: SVGProps<SVGSVGElement> & { d: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden className="h-4 w-4 shrink-0" {...props}>
      <path d={d} />
    </svg>
  )
}

export const icons = {
  overview: 'M3 12h18M3 6h18M3 18h18',
  catalog: 'M4 7h16M4 12h16M4 17h10',
  learning: 'M4 19V5l8-2 8 2v14l-8 2-8-2zM12 5v14',
  law: 'M12 3v18M5 8h14M6 8l-3 10h6M18 8l3 10h-6',
  profiles: 'M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4zM4 20a8 8 0 0 1 16 0',
  questions: 'M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4z',
  lessons: 'M8 7V3m8 4V3M5 11h14M6 5h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z',
  students: 'M16 11a3 3 0 1 0-3-3 3 3 0 0 0 3 3zM8 13a3 3 0 1 0-3-3 3 3 0 0 0 3 3zM2 20a6 6 0 0 1 12 0M12 20a6 6 0 0 1 10 0',
  payments: 'M4 7h16v10H4zM4 11h16M8 15h3',
  approvals: 'M9 11l3 3 6-6M5 19h14a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2z',
  mail: 'M4 6h16v12H4zM4 8l8 6 8-6',
  staff: 'M16 11a3 3 0 1 0-3-3 3 3 0 0 0 3 3zM4 20a6 6 0 0 1 12 0M19 8v6M22 11h-6',
  account: 'M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4zM6 20a6 6 0 0 1 12 0',
  menu: 'M4 7h16M4 12h16M4 17h16',
  search: 'M11 19a8 8 0 1 1 8-8 8 8 0 0 1-8 8zM21 21l-4.3-4.3',
}

export function StatCard({ label, value, hint }: { label: string; value: number | string; hint?: string }) {
  return (
    <div className="rounded-2xl border border-line bg-white px-4 py-3">
      <p className="text-2xl font-semibold tabular-nums">{value}</p>
      <p className="text-sm text-muted">{label}</p>
      {hint ? <p className="mt-1 text-xs text-muted">{hint}</p> : null}
    </div>
  )
}

export function Badge({ tone = 'sand', children }: { tone?: 'sand' | 'teal' | 'amber' | 'red'; children: ReactNode }) {
  const tones = {
    sand: 'bg-sand text-ink',
    teal: 'bg-teal/10 text-teal',
    amber: 'bg-amber-100 text-amber-900',
    red: 'bg-red-50 text-red-800',
  }
  return <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-semibold capitalize ${tones[tone]}`}>{children}</span>
}

export function statusTone(status: string): 'sand' | 'teal' | 'amber' | 'red' {
  if (['approved', 'verified', 'active', 'completed', 'answered'].includes(status)) return 'teal'
  if (['pending', 'open', 'scheduled', 'live'].includes(status)) return 'amber'
  if (['rejected', 'closed', 'cancelled', 'expired'].includes(status)) return 'red'
  return 'sand'
}

export function useTable<T>(rows: T[], match: (row: T, q: string) => boolean, pageSize = 10) {
  const [q, setQ] = useState('')
  const [page, setPage] = useState(1)
  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    return needle ? rows.filter((row) => match(row, needle)) : rows
  }, [rows, q, match])
  const pages = Math.max(1, Math.ceil(filtered.length / pageSize))
  const current = Math.min(page, pages)
  const slice = filtered.slice((current - 1) * pageSize, current * pageSize)

  useEffect(() => {
    if (page !== current) setPage(current)
  }, [current, page])

  return { q, setQ, page: current, setPage, pages, total: filtered.length, rows: slice, all: filtered, pageSize }
}

export function Toolbar({
  q,
  onSearch,
  placeholder,
  children,
}: {
  q: string
  onSearch: (value: string) => void
  placeholder: string
  children?: ReactNode
}) {
  return (
    <div className="mb-3 flex flex-wrap items-center gap-3">
      <label className="relative min-w-0 flex-1">
        <span className="sr-only">{placeholder}</span>
        <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-muted">
          <Icon d={icons.search} />
        </span>
        <input
          value={q}
          onChange={(event) => onSearch(event.target.value)}
          placeholder={placeholder}
          className="w-full rounded-xl border border-line bg-white py-2.5 pr-3 pl-10 text-sm"
        />
      </label>
      {children}
    </div>
  )
}

export function DataTable({
  columns,
  children,
  empty,
}: {
  columns: string[]
  children: ReactNode
  empty?: string
}) {
  return (
    <div className="overflow-hidden rounded-3xl border border-line bg-white">
      <div className="overflow-x-auto">
        <table className="w-full min-w-[36rem] text-left text-sm">
          <thead className="border-b border-line bg-sand/70 text-xs tracking-wide text-muted uppercase">
            <tr>
              {columns.map((column) => (
                <th key={column} className="px-4 py-3 font-semibold">
                  {column}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-line">{children}</tbody>
        </table>
      </div>
      {empty ? <p className="px-4 py-8 text-center text-sm text-muted">{empty}</p> : null}
    </div>
  )
}

export function Pager({ page, pages, total, pageSize, onPage }: { page: number; pages: number; total: number; pageSize: number; onPage: (page: number) => void }) {
  const from = total === 0 ? 0 : (page - 1) * pageSize + 1
  const to = Math.min(page * pageSize, total)
  return (
    <div className="mt-3 flex flex-wrap items-center justify-between gap-3 text-sm text-muted">
      <p>
        {from}–{to} of {total}
      </p>
      <div className="flex gap-2">
        <button type="button" disabled={page <= 1} onClick={() => onPage(page - 1)} className="rounded-lg border border-line bg-white px-3 py-1.5 font-semibold text-ink disabled:opacity-40">
          Previous
        </button>
        <button type="button" disabled={page >= pages} onClick={() => onPage(page + 1)} className="rounded-lg border border-line bg-white px-3 py-1.5 font-semibold text-ink disabled:opacity-40">
          Next
        </button>
      </div>
    </div>
  )
}

export function FilterPills({
  value,
  options,
  onChange,
}: {
  value: string
  options: Array<{ id: string; label: string }>
  onChange: (id: string) => void
}) {
  return (
    <div className="flex flex-wrap gap-2">
      {options.map((option) => (
        <button
          key={option.id}
          type="button"
          onClick={() => onChange(option.id)}
          className={`rounded-full px-3 py-1.5 text-xs font-semibold ${value === option.id ? 'bg-teal text-white' : 'border border-line bg-white text-ink'}`}
        >
          {option.label}
        </button>
      ))}
    </div>
  )
}
