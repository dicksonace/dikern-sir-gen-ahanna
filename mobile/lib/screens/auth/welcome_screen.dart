import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool? apiOnline;

  @override
  void initState() {
    super.initState();
    _checkApi();
  }

  Future<void> _checkApi() async {
    final ok = await context.read<ApiClient>().health();
    if (mounted) setState(() => apiOnline = ok);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: GradientHeader(
              height: MediaQuery.sizeOf(context).height * 0.48,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'LIVE API',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _ApiBadge(online: apiOnline),
                      ],
                    ).animate().fadeIn(),
                    const SizedBox(height: 18),
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Image.asset('assets/images/app_logo.png', fit: BoxFit.contain),
                    )
                        .animate()
                        .fadeIn(delay: 80.ms)
                        .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
                    const Spacer(),
                    Text(
                      'සර් ගෙන්\nඅහන්න',
                      style: GoogleFonts.sora(
                        color: Colors.white,
                        fontSize: 42,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.15),
                    const SizedBox(height: 14),
                    Text(
                      'Weekly live tutoring + instant help when homework gets stuck.',
                      style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ).animate().fadeIn(delay: 220.ms),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SoftCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sign in with demo account',
                      style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connected to ${ApiConfig.baseUrl}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    _QuickLogin(
                      title: 'Student',
                      subtitle: 'student@sirgen.lk',
                      icon: Icons.school_rounded,
                      email: 'student@sirgen.lk',
                    ),
                    const SizedBox(height: 10),
                    _QuickLogin(
                      title: 'Tutor',
                      subtitle: 'nimal@sirgen.lk',
                      icon: Icons.record_voice_over_rounded,
                      email: 'nimal@sirgen.lk',
                    ),
                    const SizedBox(height: 10),
                    _QuickLogin(
                      title: 'Administrator',
                      subtitle: 'admin@sirgen.lk',
                      icon: Icons.admin_panel_settings_rounded,
                      email: 'admin@sirgen.lk',
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Manual email / password login'),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiBadge extends StatelessWidget {
  final bool? online;
  const _ApiBadge({required this.online});

  @override
  Widget build(BuildContext context) {
    final color = online == null
        ? Colors.white54
        : online!
            ? const Color(0xFF7DDE92)
            : const Color(0xFFFF8A80);
    final label = online == null ? 'Checking…' : online! ? 'API online' : 'API offline';
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _QuickLogin extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String email;

  const _QuickLogin({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.email,
  });

  @override
  State<_QuickLogin> createState() => _QuickLoginState();
}

class _QuickLoginState extends State<_QuickLogin> {
  bool loading = false;

  Future<void> _login() async {
    setState(() => loading = true);
    final auth = context.read<AuthState>();
    try {
      await auth.login(widget.email, 'password');
      if (!mounted) return;
      context.go(auth.homeRouteForRole());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sand,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : _login,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: AppColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(widget.subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'student@sirgen.lk');
  final password = TextEditingController(text: 'password');
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => loading = true);
    final auth = context.read<AuthState>();
    try {
      await auth.login(email.text, password.text);
      if (!mounted) return;
      context.go(auth.homeRouteForRole());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SoftCard(
            child: Column(
              children: [
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sign in'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
