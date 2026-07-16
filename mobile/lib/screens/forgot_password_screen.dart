import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _obscure = true;

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      showError(context, 'Please enter a valid email address.');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AppState>().forgotPassword(email);
      if (!mounted) return;
      setState(() => _codeSent = true);
      showSuccess(context, 'If that email exists, a code is on its way.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_code.text.trim().length != 6) {
      showError(context, 'Enter the 6-digit code from your email.');
      return;
    }
    if (_newPassword.text.length < 8) {
      showError(context, 'Password must be at least 8 characters.');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AppState>().resetPassword(
            _email.text.trim(),
            _code.text.trim(),
            _newPassword.text,
          );
      if (!mounted) return;
      showSuccess(context, 'Password updated. Please sign in.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final curved =
                      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
                child: _codeSent ? _buildResetStep() : _buildRequestStep(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestStep() {
    return Column(
      key: const ValueKey('request'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset, size: 72, color: AppColors.maroon),
        const SizedBox(height: 16),
        Text(
          'Forgot your password?',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: AppColors.maroon),
        ),
        const SizedBox(height: 8),
        const Text(
          "Enter your email and we'll send you a 6-digit code to reset it.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 24),
        BigButton(
          label: 'Send reset code',
          icon: Icons.send,
          loading: _loading,
          onPressed: _sendCode,
        ),
      ],
    );
  }

  Widget _buildResetStep() {
    return Column(
      key: const ValueKey('reset'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read, size: 72, color: AppColors.peacock),
        const SizedBox(height: 16),
        Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: AppColors.maroon),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the code sent to ${_email.text.trim()} and choose a new password.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, letterSpacing: 8),
          decoration: const InputDecoration(
            labelText: '6-digit code',
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newPassword,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'New password',
            suffixIcon: IconButton(
              iconSize: 28,
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 24),
        BigButton(
          label: 'Reset password',
          icon: Icons.check_circle,
          loading: _loading,
          onPressed: _resetPassword,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                    _codeSent = false;
                    _code.clear();
                  }),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }
}
