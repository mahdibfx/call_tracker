import 'package:flutter/material.dart';
import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/data/models.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/views/login/login_view.dart';
import 'package:call_tracker/ui/views/root/root_view.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Permission.phone.request();
  // Android 13+. Without it the agent gets no prompt for a call that came in
  // while the app was closed — it would only surface when he next opens it.
  await Permission.notification.request();

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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

/// Shows the login screen until an agent session exists, then the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<Agent?> _agent = AuthService.currentAgent();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _agent,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.backgroundColor,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data != null ? const RootView() : const LoginView();
      },
    );
  }
}
