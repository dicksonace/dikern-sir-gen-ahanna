import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/api_client.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _boot();
  }

  Future<void> _boot() async {
    final auth = context.read<AuthState>();
    final api = context.read<ApiClient>();

    // Let the logo animation play, and probe API in parallel.
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 2400)),
      api.health(),
      Future(() async {
        while (auth.booting) {
          await Future.delayed(const Duration(milliseconds: 40));
        }
      }),
    ]);

    if (!mounted || _leaving) return;
    _leaving = true;

    final online = results[1] as bool;
    if (!online && mounted) {
      // brief beat so user sees the branded splash even if API is down
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;
    if (auth.isLoggedIn) {
      context.go(auth.homeRouteForRole());
    } else {
      context.go('/welcome');
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D7377),
              Color(0xFF14919B),
              Color(0xFF1B4965),
            ],
          ),
        ),
        child: Stack(
          children: [
            // soft floating orbs
            Positioned(
              top: -60,
              right: -40,
              child: _Orb(size: 200, color: Colors.white.withValues(alpha: 0.08))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: 18, duration: 3200.ms, curve: Curves.easeInOut),
            ),
            Positioned(
              bottom: 80,
              left: -50,
              child: _Orb(size: 160, color: AppColors.amber.withValues(alpha: 0.16))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -14, duration: 2800.ms, curve: Curves.easeInOut),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: Tween(begin: 0.96, end: 1.04).animate(
                        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 132,
                          height: 132,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 700.ms),
                    const SizedBox(height: 28),
                    Text(
                      'සර් ගෙන් අහන්න',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sora(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 280.ms, duration: 500.ms)
                        .slideY(begin: 0.25, end: 0, delay: 280.ms, curve: Curves.easeOutCubic),
                    const SizedBox(height: 10),
                    Text(
                      'Ask your tutor anytime',
                      style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 480.ms, duration: 450.ms),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          color: AppColors.amber,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 650.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
