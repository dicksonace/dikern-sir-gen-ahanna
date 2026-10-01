import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { api, getToken, setToken, type AdminUser } from './api'

type AuthValue = {
  user: AdminUser | null
  ready: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
}

const AuthContext = createContext<AuthValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null)
  const [ready, setReady] = useState(false)

  useEffect(() => {
    if (!getToken()) {
      setReady(true)
      return
    }

    api<AdminUser>('/me')
      .then((me) => {
        if (me.role !== 'admin') {
          setToken(null)
          setUser(null)
          return
        }
        setUser(me)
      })
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
      async login(email, password) {
        const result = await api<{ token: string; user: AdminUser }>('/admin/login', {
          method: 'POST',
          body: JSON.stringify({ email, password }),
        })
        setToken(result.token)
        setUser(result.user)
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
