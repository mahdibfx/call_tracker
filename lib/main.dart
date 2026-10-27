import 'package:flutter/material.dart';
import 'package:call_tracker/data/api_service.dart';
import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/views/login/login_view.dart';
import 'package:call_tracker/ui/views/root/app_area.dart';
import 'package:call_tracker/ui/views/root/root_view.dart';
import 'package:permission_handler/permission_handler.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A 401 from any authenticated call means the token expired or the agent was
  // blocked. Drop the session and unwind to the root, so the agent lands on the
  // login screen instead of staring at a list that silently stopped refreshing.
  ApiService.onUnauthorized = () async {
    if (await AuthService.expire()) {
      appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  };

  await AuthService.restore();
  await Permission.phone.request();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.backgroundColor,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryColor),
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

/// Shows the login screen until someone is signed in, and swaps back the
/// moment the session ends — no screen has to navigate to or from login.
///
/// Also decides which areas of the app the signed-in staff member gets. It may
/// assume the user is not a teacher: teachers are refused in `AuthService`,
/// both at login and when a stored session is re-checked.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Agent?>(
      valueListenable: AuthService.signedIn,
      builder: (context, user, _) {
        if (user == null) return const LoginView();
        // A session stored before roles existed. `AuthService.restore` is
        // completing it against the backend; there is nothing to route on
        // until it does.
        if (user.role == null) return const _SessionLoadingView();
        return RootView(areas: AppArea.forUser(user));
      },
    );
  }
}

class _SessionLoadingView extends StatelessWidget {
  const _SessionLoadingView();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
}
