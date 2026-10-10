const TOKEN_KEY = 'sirgen_admin_token'

export type AdminUser = {
  id: number
  name: string
  email: string
  role: string
}

export type PendingProfile = {
  id: number
  status: string
  user?: {
    id: number
    name: string
    email: string
    role: string
    division: string
  }
}

export type Overview = {
  learning: { students: number; tutors: number; lecturers: number }
  law: { clients: number; lawyers: number; counsel: number }
  pending_profiles: number
  pending_kyc: number
  pending_payments: number
  open_questions: number
  pending: PendingProfile[]
  charts: {
    people: Array<{ label: string; value: number; side: 'learning' | 'law' }>
    tracks: Array<{
      name: string
      slug: string
      kind: 'subjects' | 'programme'
      subjects: Array<{ name: string; slug: string; tutors: number; questions: number }>
    }>
    law_areas: Array<{ name: string; slug: string; people: number; questions: number }>
    questions: Array<{ label: string; value: number }>
    lessons: Array<{ label: string; value: number }>
    payments: Array<{ label: string; value: number; amount: number }>
  }
}

export class ApiError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

export function getToken() {
  return localStorage.getItem(TOKEN_KEY)
}

export function setToken(token: string | null) {
  if (token) localStorage.setItem(TOKEN_KEY, token)
  else localStorage.removeItem(TOKEN_KEY)
}

export async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers = new Headers(options.headers)
  headers.set('Accept', 'application/json')
  if (options.body) headers.set('Content-Type', 'application/json')
  const token = getToken()
  if (token) headers.set('Authorization', `Bearer ${token}`)

  const root = import.meta.env.VITE_API_URL ?? ''
  const response = await fetch(`${root}/api${path}`, { ...options, headers })
  const text = await response.text()
  const data = text ? JSON.parse(text) : null

  if (!response.ok) {
    const firstError = data?.errors ? Object.values(data.errors as Record<string, string[]>)[0]?.[0] : undefined
    const message = firstError || data?.message || `Request failed (${response.status})`
    throw new ApiError(message, response.status)
  }

  return data as T
}
