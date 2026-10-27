import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { api, getToken, setToken, type AdminUser } from './api'

type AuthValue = {
  user: AdminUser | null
  ready: boolean
  login: (email: string, password: string) => Promise<AdminUser>
  logout: () => Promise<void>
  refresh: () => Promise<void>
  setUser: (user: AdminUser | null) => void
}

const AuthContext = createContext<AuthValue | null>(null)

function asAdmin(raw: AdminUser & { pages?: string[] | null }): AdminUser | null {
  if (raw.role !== 'admin') return null
  return {
    id: raw.id,
    name: raw.name,
    email: raw.email,
    phone: raw.phone ?? null,
    role: raw.role,
    pages: raw.pages ?? null,
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null)
  const [ready, setReady] = useState(false)

  useEffect(() => {
    if (!getToken()) {
      setReady(true)
      return
    }

    api<AdminUser>('/me')
      .then((me) => setUser(asAdmin(me)))
      .catch(() => {
        setToken(null)
        setUser(null)
      })
      .finally(() => setReady(true))
  }, [])

  const value = useMemo<AuthValue>(
    () => ({
      user,
      ready,
      setUser,
      async refresh() {
        const me = asAdmin(await api<AdminUser>('/me'))
        if (!me) {
          setToken(null)
          setUser(null)
          return
        }
        setUser(me)
      },
      async login(email, password) {
        const result = await api<{ token: string; user: AdminUser }>('/admin/login', {
          method: 'POST',
          body: JSON.stringify({ email, password }),
        })
        const next = asAdmin(result.user)
        if (!next) {
          setToken(null)
          throw new Error('Admin sign-in only.')
        }
        setToken(result.token)
        setUser(next)
        return next
      },
      async logout() {
        try {
          await api('/logout', { method: 'POST' })
        } catch {
          // The local token is cleared either way.
        }
        setToken(null)
        setUser(null)
      },
    }),
    [user, ready],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const value = useContext(AuthContext)
  if (!value) throw new Error('useAuth must be used inside AuthProvider')
  return value
}
