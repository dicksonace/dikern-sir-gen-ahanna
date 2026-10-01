import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './auth'
import { DashboardPage } from './pages/Dashboard'
import { LandingPage } from './pages/Landing'
import { LawPage } from './pages/Law'
import { LearningPage } from './pages/Learning'
import { LoginPage } from './pages/Login'

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<LandingPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="/learning" element={<Navigate to="/learning/a-l" replace />} />
          <Route path="/learning/:slug" element={<LearningPage />} />
          <Route path="/law" element={<Navigate to="/law/family-law" replace />} />
          <Route path="/law/:slug" element={<LawPage />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}
