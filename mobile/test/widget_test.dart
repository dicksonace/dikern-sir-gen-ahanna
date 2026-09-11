import 'package:flutter_test/flutter_test.dart';
import 'package:sir_gen_ahanna/main.dart';
import 'package:sir_gen_ahanna/router/app_router.dart';
import 'package:sir_gen_ahanna/services/api_client.dart';
import 'package:sir_gen_ahanna/state/auth_state.dart';

void main() {
  testWidgets('App boots', (tester) async {
    final api = ApiClient();
    final auth = AuthState(api);
    final router = createRouter(auth);
    await tester.pumpWidget(SirGenAhannaApp(api: api, auth: auth, router: router));
    await tester.pump();
    expect(find.textContaining('සර්'), findsWidgets);
  });
}
