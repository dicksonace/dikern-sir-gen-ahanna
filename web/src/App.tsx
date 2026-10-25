import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './auth'
import { ApprovalsPage } from './pages/Approvals'
import { DashboardPage } from './pages/Dashboard'
import { LandingPage } from './pages/Landing'
import { LawPage } from './pages/Law'
import { LearningPage } from './pages/Learning'
import { LessonsPage } from './pages/Lessons'
import { LoginPage } from './pages/Login'
import { PaymentsPage } from './pages/Payments'
import { ProfilesPage } from './pages/Profiles'
import { QuestionsPage } from './pages/Questions'
import { StudentsPage } from './pages/Students'

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter basename={import.meta.env.BASE_URL.replace(/\/$/, '') || undefined}>
        <Routes>
          <Route path="/" element={<LandingPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="/profiles" element={<ProfilesPage />} />
          <Route path="/questions" element={<QuestionsPage />} />
          <Route path="/lessons" element={<LessonsPage />} />
          <Route path="/students" element={<StudentsPage />} />
          <Route path="/payments" element={<PaymentsPage />} />
          <Route path="/approvals" element={<ApprovalsPage />} />
          <Route path="/learning" element={<Navigate to="/learning/a-l" replace />} />
          <Route path="/learning/:slug" element={<LearningPage />} />
          <Route path="/law" element={<Navigate to="/law/family-law" replace />} />
          <Route path="/law/:slug" element={<LawPage />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}
