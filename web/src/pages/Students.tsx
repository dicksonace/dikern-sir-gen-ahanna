import { roleLabel, type AccountRow } from '../api'
import { Badge, DataTable, FilterPills, Pager, StatCard, Toolbar, useTable } from '../ui'
import { PageFrame, useDeskLoad } from './Desk'
import { useState } from 'react'

function matchAccount(row: AccountRow, q: string) {
  return `${row.name} ${row.email} ${row.phone ?? ''} ${row.role} ${row.division}`.toLowerCase().includes(q)
}

export function StudentsPage() {
  const { data: accounts, error } = useDeskLoad<AccountRow[]>('/admin/accounts', [])
  const [side, setSide] = useState('all')
  const filtered = accounts.filter((row) => (side === 'all' ? true : row.division === side))
  const table = useTable(filtered, matchAccount)

  return (
    <PageFrame
      eyebrow="People"
      title="Students and clients"
      note="People who learn or ask for advice. Teachers stay in Profiles."
      error={error}
    >
      <div className="mb-6 grid gap-3 sm:grid-cols-3">
        <StatCard label="Students" value={accounts.filter((row) => row.role === 'student').length} />
        <StatCard label="Clients" value={accounts.filter((row) => row.role === 'client').length} />
        <StatCard label="On this page" value={table.total} />
      </div>
      <Toolbar q={table.q} onSearch={(value) => { table.setQ(value); table.setPage(1) }} placeholder="Search name, email, or phone">
        <FilterPills
          value={side}
          onChange={(id) => { setSide(id); table.setPage(1) }}
          options={[
            { id: 'all', label: 'All' },
            { id: 'tutor', label: 'Learning' },
            { id: 'law', label: 'Law' },
          ]}
        />
      </Toolbar>
      <DataTable columns={['Name', 'Side', 'Role', 'Contact']} empty={table.total === 0 ? 'No student or client accounts match.' : undefined}>
        {table.rows.map((account) => (
          <tr key={account.id}>
            <td className="px-4 py-3 font-semibold">{account.name}</td>
            <td className="px-4 py-3">{account.division === 'law' ? 'Law advice' : 'Learning'}</td>
            <td className="px-4 py-3">
              <Badge>{roleLabel[account.role] ?? account.role}</Badge>
            </td>
            <td className="px-4 py-3 text-muted">
              {account.email}
              {account.phone ? ` · ${account.phone}` : ''}
            </td>
          </tr>
        ))}
      </DataTable>
      <Pager page={table.page} pages={table.pages} total={table.total} pageSize={table.pageSize} onPage={table.setPage} />
    </PageFrame>
  )
}
