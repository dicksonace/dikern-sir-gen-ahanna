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
    identity_document?: { id: number; status: string } | null
  }
}

export type TeacherProfile = {
  id: number
  status: string
  bio: string | null
  qualifications: string | null
  experience: string | null
  satisfaction_points: number
  user?: {
    id: number
    name: string
    email: string
    phone: string | null
    role: string
    division: string
    identity_document?: { id: number; kind: string; status: string; note: string | null } | null
  }
  subjects?: Array<{ id: number; name: string }>
}

export const roleLabel: Record<string, string> = {
  student: 'Student',
  tutor: 'Tutor',
  lecturer: 'Lecturer',
  client: 'Client',
  lawyer: 'Lawyer',
  counsel: 'Legal counsel',
}

export type QuestionRow = {
  id: number
  body: string | null
  status: string
  has_attachment: boolean
  student?: { name: string; role: string; division: string } | null
  tutor?: { name: string; role: string } | null
  subject?: { name: string } | null
  replies?: Array<{
    id: number
    content: string | null
    has_attachment: boolean
    tutor?: { name: string } | null
  }>
}

export type LessonRow = {
  id: number
  title: string
  scheduled_at: string | null
  status: string
  student?: { name: string } | null
  tutor?: { name: string } | null
}

export type AccountRow = {
  id: number
  name: string
  email: string
  phone: string | null
  role: string
  division: string
}

export type PaymentReview = {
  id: number
  amount: string
  has_slip: boolean
  student?: { name: string; email: string } | null
  subscription?: {
    package?: { name: string } | null
    tutor?: { name: string } | null
  } | null
}

export type KycDocument = {
  id: number
  kind: string
  status: string
  user?: {
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

export function apiRoot() {
  return import.meta.env.VITE_API_URL ?? ''
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

  const root = apiRoot()
  const response = await fetch(`${root}/api${path}`, { ...options, headers, cache: 'no-store' })
  const text = await response.text()
  const data = text ? JSON.parse(text) : null

  if (!response.ok) {
    const firstError = data?.errors ? Object.values(data.errors as Record<string, string[]>)[0]?.[0] : undefined
    const message = firstError || data?.message || `Request failed (${response.status})`
    throw new ApiError(message, response.status)
  }

  return data as T
}
