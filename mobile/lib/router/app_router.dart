import 'package:go_router/go_router.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/shared/detail_screens.dart';
import '../screens/student/student_shell.dart';
import '../screens/tutor/tutor_shell.dart';
import '../state/auth_state.dart';

GoRouter createRouter(AuthState auth) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final loc = state.matchedLocation;
      final public = loc == '/' || loc == '/welcome' || loc == '/login';

      if (auth.booting) return null;

      // Splash owns the first navigation after boot.
      if (loc == '/') return null;

      if (!loggedIn && !public) return '/welcome';
      if (loggedIn && (loc == '/welcome' || loc == '/login')) {
        return auth.homeRouteForRole();
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/student', builder: (context, state) => const StudentShell()),
      GoRoute(path: '/tutor', builder: (context, state) => const TutorShell()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminShell()),
      GoRoute(
        path: '/tutor-profile/:id',
        builder: (context, state) => TutorProfileScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/payment/:packageId',
        builder: (context, state) {
          final tutorId = int.tryParse(state.uri.queryParameters['tutorId'] ?? '');
          return PaymentScreen(
            packageId: state.pathParameters['packageId']!,
            tutorId: tutorId,
          );
        },
      ),
      GoRoute(path: '/live-lesson', builder: (context, state) => const LiveLessonScreen()),
    ],
  );
}
