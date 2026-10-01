import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'router/app_router.dart';
import 'services/api_client.dart';
import 'state/app_settings.dart';
import 'state/auth_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final api = ApiClient();
  final auth = AuthState(api);
  final settings = AppSettings();
  await Future.wait([auth.bootstrap(), settings.load()]);
  final router = createRouter(auth);

  runApp(SirGenAhannaApp(api: api, auth: auth, settings: settings, router: router));
}

class SirGenAhannaApp extends StatelessWidget {
  final ApiClient api;
  final AuthState auth;
  final AppSettings settings;
  final GoRouter router;

  const SirGenAhannaApp({
    super.key,
    required this.api,
    required this.auth,
    required this.settings,
    required this.router,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'සර් ගෙන් අහන්න',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.mode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
