import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/api_config.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../shared/account_forms.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String side = 'tutor';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: GradientHeader(
              height: MediaQuery.sizeOf(context).height * 0.36,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
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
                      'Weekly tutoring, or legal advice — pick the side you need.',
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
                      'Sign in with a demo account',
                      style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Connected to ${ApiConfig.baseUrl}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _SideChip(
                          label: 'Tutor',
                          selected: side == 'tutor',
                          onTap: () => setState(() => side = 'tutor'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _SideChip(
                          label: 'Law advice',
                          selected: side == 'law',
                          onTap: () => setState(() => side = 'law'),
                        )),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ..._rolesFor(side),
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

class _SideChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.teal : AppColors.sand,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

List<Widget> _rolesFor(String side) {
  final roles = side == 'law'
      ? const [
          _Role('Client', 'client@sirgen.lk', Icons.person_rounded),
          _Role('Lawyer', 'lawyer@sirgen.lk', Icons.balance_rounded),
          _Role('Legal counsel', 'counsel@sirgen.lk', Icons.gavel_rounded),
        ]
      : const [
          _Role('Student', 'student@sirgen.lk', Icons.school_rounded),
          _Role('Tutor', 'nimal@sirgen.lk', Icons.record_voice_over_rounded),
          _Role('Lecturer', 'lecturer@sirgen.lk', Icons.co_present_rounded),
        ];

  return [
    for (var i = 0; i < roles.length; i++) ...[
      if (i > 0) const SizedBox(height: 10),
      _QuickLogin(title: roles[i].title, subtitle: roles[i].email, icon: roles[i].icon, email: roles[i].email),
    ],
  ];
}

class _Role {
  final String title;
  final String email;
  final IconData icon;
  const _Role(this.title, this.email, this.icon);
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordScreen(initialEmail: email.text.trim()),
                      ),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),
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
