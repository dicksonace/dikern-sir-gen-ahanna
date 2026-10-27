const TOKEN_KEY = 'sirgen_admin_token'

export type AdminUser = {
  id: number
  name: string
  email: string
  phone?: string | null
  role: string
  pages: string[] | null
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
  duration_minutes?: number
  status: string
  student?: { name: string } | null
  tutor?: { name: string } | null
}

export type PackageRow = {
  id: number
  name: string
  division: 'tutor' | 'law'
  description: string | null
  price: number | string
  weekly_hours: number
  includes_instant_questions: boolean
  includes_screen_share: boolean
  is_active: boolean
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
  status: string
  has_slip: boolean
  created_at?: string
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

export const ADMIN_PAGES = [
  { id: 'dashboard', label: 'Overview' },
  { id: 'catalog', label: 'Catalog' },
  { id: 'learning', label: 'Learning' },
  { id: 'law', label: 'Law advice' },
  { id: 'profiles', label: 'Profiles' },
  { id: 'questions', label: 'Questions' },
  { id: 'lessons', label: 'Lessons' },
  { id: 'students', label: 'Students' },
  { id: 'payments', label: 'Payments' },
  { id: 'approvals', label: 'Approvals' },
  { id: 'mail', label: 'Mail queue' },
  { id: 'staff', label: 'Staff' },
  { id: 'account', label: 'My profile' },
] as const

export function canOpen(user: AdminUser | null, page: string) {
  if (!user || user.role !== 'admin') return false
  if (page === 'account' || user.pages == null) return true
  return user.pages.includes(page)
}

export function firstOpenPath(user: AdminUser | null) {
  if (canOpen(user, 'dashboard')) return '/dashboard'
  const match = ADMIN_PAGES.find((page) => canOpen(user, page.id))
  return match ? pathForPage(match.id) : '/account'
}

export function pathForPage(page: string) {
  if (page === 'learning') return '/learning/a-l'
  if (page === 'law') return '/law/family-law'
  if (page === 'dashboard') return '/dashboard'
  if (page === 'account') return '/account'
  return `/${page}`
}

export function pageForPath(pathname: string) {
  if (pathname.startsWith('/learning')) return 'learning'
  if (pathname.startsWith('/law')) return 'law'
  if (pathname.startsWith('/dashboard')) return 'dashboard'
  const top = pathname.split('/').filter(Boolean)[0] ?? 'dashboard'
  return top
}

export type Overview = {
  learning: { students: number; tutors: number; lecturers: number }
  law: { clients: number; lawyers: number; counsel: number }
  pending_profiles: number
  pending_kyc: number
  pending_payments: number
  open_questions: number
  totals?: {
    people: number
    new_people: number
    approved_teachers: number
    active_subscriptions: number
    waiting_subscriptions: number
    lessons: number
    questions: number
    payments_waiting_rs: number
    payments_received_rs: number
    commission_waiting_rs: number
    mail_waiting: number
    mail_failed: number
  }
  recent?: {
    people: Array<{ id: number; name: string; email: string; role: string; division: string; created_at: string }>
    payments: PaymentReview[]
    questions: Array<{
      id: number
      body: string | null
      status: string
      student?: { name: string; division: string } | null
      tutor?: { name: string } | null
      subject?: { name: string } | null
    }>
  }
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
