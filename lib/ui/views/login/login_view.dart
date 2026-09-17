import 'package:flutter/material.dart';
import 'package:call_tracker/data/auth_service.dart';
import 'package:call_tracker/ui/common/app_colors.dart';
import 'package:call_tracker/ui/common/app_styles.dart';
import 'package:call_tracker/ui/common/ui_helpers.dart';
import 'package:call_tracker/ui/widgets/custom_button.dart';
import 'package:call_tracker/ui/widgets/custom_input.dart';
import 'package:call_tracker/ui/widgets/custom_text.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Shown once when the session ended on its own, so the agent knows why
    // they're back here rather than assuming the app logged them out at random.
    _error = AuthService.endedReason;
    AuthService.endedReason = null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final failure = await AuthService.signIn(email, password);
    if (!mounted) return;
    // On success AuthService flips the signed-in state and AuthGate swaps this
    // screen out — nothing to navigate to from here.
    setState(() {
      _loading = false;
      _error = failure?.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColorLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryColor, width: 1.5),
                  ),
                  child: const Icon(Icons.call, color: AppColors.primaryColor, size: 40),
                ),
                verticalSpaceMedium,
                CustomText.title(text: 'Language Institute', fontSize: 22),
                const SizedBox(height: 4),
                CustomText.subtitle(text: 'Call Tracker — Agent Login'),
                verticalSpaceLarge,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(AppStyles.borderRadiusLargeValue),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomText.bodyBold(text: 'Email', fontSize: 13),
                      const SizedBox(height: 6),
                      CustomInput(
                        hintText: 'you@institute.com',
                        controller: _emailController,
                        prefixIcon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      verticalSpaceMedium,
                      CustomText.bodyBold(text: 'Password', fontSize: 13),
                      const SizedBox(height: 6),
                      CustomInput(
                        hintText: 'Your password',
                        controller: _passwordController,
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      if (_error != null) ...[
                        verticalSpaceSmall,
                        Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: AppColors.redColor),
                            horizontalSpaceTiny,
                            Expanded(
                              child: CustomText.body(text: _error!, textColor: AppColors.redColor, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                      verticalSpaceMedium,
                      CustomButton(
                        text: _loading ? 'Logging in...' : 'Log In',
                        onPressed: _loading ? null : _submit,
                      ),
                    ],
                  ),
                ),
                verticalSpaceMedium,
                CustomText.caption(
                  text: "Don't have an account? Ask your supervisor to create one from the dashboard.",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
