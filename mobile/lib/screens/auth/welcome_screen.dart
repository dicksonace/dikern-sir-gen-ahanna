import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../shared/account_forms.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: _AuthBody(registering: false));
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: _AuthBody(registering: false));
  }
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: _AuthBody(registering: true));
  }
}

class _AuthBody extends StatefulWidget {
  final bool registering;
  const _AuthBody({required this.registering});

  @override
  State<_AuthBody> createState() => _AuthBodyState();
}

class _AuthBodyState extends State<_AuthBody> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final code = TextEditingController();
  String side = 'tutor';
  String role = 'student';
  bool loading = false;
  bool hidePassword = true;
  bool awaitingCode = false;

  static const learningRoles = [
    ('student', 'Student'),
    ('tutor', 'Tutor'),
    ('lecturer', 'Lecturer'),
  ];
  static const lawRoles = [
    ('client', 'Client'),
    ('lawyer', 'Lawyer'),
    ('counsel', 'Legal counsel'),
  ];

  List<(String, String)> get roles => side == 'law' ? lawRoles : learningRoles;
  String get sideName => side == 'law' ? 'Law advice' : 'Learning';

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    confirm.dispose();
    code.dispose();
    super.dispose();
  }

  void _setSide(String next) {
    setState(() {
      side = next;
      role = next == 'law' ? 'client' : 'student';
    });
  }

  Future<void> _submit() async {
    final address = email.text.trim();
    if (address.isEmpty || password.text.isEmpty || (widget.registering && name.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in your name, email, and password.')),
      );
      return;
    }
    if (widget.registering && password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }
    setState(() => loading = true);
    final auth = context.read<AuthState>();
    try {
      if (widget.registering) {
        final data = await auth.register(
          name: name.text,
          email: address,
          password: password.text,
          role: role,
          phone: phone.text.trim(),
        );
        if (!mounted) return;
        if (data['verification_required'] == true) {
          final sent = data['verification_code'];
          setState(() {
            awaitingCode = true;
            if (sent is String) code.text = sent;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('We emailed a confirmation code. Enter it to finish.')),
          );
          return;
        }
      } else {
        await auth.login(address, password.text, division: side);
      }
      if (!mounted) return;
      context.go(auth.homeRouteForRole());
    } catch (e) {
      if (!mounted) return;
      if ('$e'.contains('Confirm your email')) {
        setState(() => awaitingCode = true);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _confirmEmail() async {
    if (code.text.trim().isEmpty) return;
    setState(() => loading = true);
    try {
      await context.read<ApiClient>().verifyEmail(
            email: email.text.trim(),
            division: side,
            code: code.text.trim(),
          );
      if (!mounted) return;
      await context.read<AuthState>().login(email.text.trim(), password.text, division: side);
      if (!mounted) return;
      context.go(context.read<AuthState>().homeRouteForRole());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => loading = true);
    try {
      await context.read<ApiClient>().resendVerification(email: email.text.trim(), division: side);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new code is on the way.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GradientHeader(
          height: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ).animate().fadeIn(delay: 80.ms),
                const SizedBox(height: 16),
                Text(
                  'සර් ගෙන්\nඅහන්න',
                  style: GoogleFonts.sora(
                    color: Colors.white,
                    fontSize: 36,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.registering
                      ? 'Create a $sideName account. The same email can also open the other side.'
                      : 'Choose a side, then sign in. One email can have both.',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: SoftCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SideTabs(side: side, onChanged: _setSide),
                const SizedBox(height: 8),
                Text(
                  side == 'law'
                      ? 'Clients, lawyers, and legal counsel.'
                      : 'Students, tutors, and lecturers.',
                  style: const TextStyle(color: AppColors.muted, height: 1.35),
                ),
                const SizedBox(height: 16),
                if (widget.registering) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in roles)
                        ChoiceChip(
                          label: Text(item.$2),
                          selected: role == item.$1,
                          onSelected: (_) => setState(() => role = item.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                if (widget.registering) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Phone (optional)'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: hidePassword,
                  textInputAction: widget.registering ? TextInputAction.next : TextInputAction.done,
                  onSubmitted: widget.registering ? null : (_) => loading ? null : _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => hidePassword = !hidePassword),
                      icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                if (widget.registering) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirm,
                    obscureText: hidePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => loading ? null : _submit(),
                    decoration: const InputDecoration(labelText: 'Confirm password'),
                  ),
                ],
                if (awaitingCode) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Email confirmation code'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: loading ? null : _confirmEmail,
                    child: const Text('Confirm email'),
                  ),
                  TextButton(
                    onPressed: loading ? null : _resendCode,
                    child: const Text('Send the code again'),
                  ),
                ],
                if (!widget.registering)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordScreen(
                            initialEmail: email.text.trim(),
                            division: side,
                          ),
                        ),
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  )
                else
                  const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(widget.registering ? 'Create $sideName account' : 'Sign in to $sideName'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(widget.registering ? '/welcome' : '/register'),
                  child: Text(widget.registering ? 'Already have an account? Sign in' : 'New here? Create an account'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SideTabs extends StatelessWidget {
  final String side;
  final ValueChanged<String> onChanged;

  const _SideTabs({required this.side, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.sand,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tab('Learning', 'tutor'),
          _tab('Law advice', 'law'),
        ],
      ),
    );
  }

  Widget _tab(String label, String value) {
    final selected = side == value;
    return Expanded(
      child: Material(
        color: selected ? AppColors.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
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
      ),
    );
  }
}
