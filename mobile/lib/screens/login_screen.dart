import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/transitions.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  bool _obscure = true;

  late final AnimationController _entranceController;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    final curved =
        CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic);
    _entranceFade = curved;
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(curved);
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_isRegister && _name.text.trim().isEmpty) {
      return 'Please enter your name.';
    }
    if (!_email.text.trim().contains('@')) {
      return 'Please enter a valid email address.';
    }
    if (_isRegister && _password.text.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (_password.text.isEmpty) {
      return 'Please enter your password.';
    }
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      showError(context, validationError);
      return;
    }
    final state = context.read<AppState>();
    setState(() => _loading = true);
    try {
      if (_isRegister) {
        await state.register(
            _name.text.trim(), _email.text.trim(), _password.text);
      } else {
        await state.login(_email.text.trim(), _password.text);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForgotPassword() {
    Navigator.of(context).push(fadeSlideRoute(const ForgotPasswordScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FadeTransition(
                opacity: _entranceFade,
                child: SlideTransition(
                  position: _entranceSlide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.family_restroom,
                          size: 80, color: AppColors.maroon),
                      const SizedBox(height: 12),
                      Text(
                        'Family Tree',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                                color: AppColors.maroon,
                                fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Keep your family history together, forever.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 18, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 36),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SizeTransition(
                              sizeFactor: animation,
                              axisAlignment: -1,
                              child: child,
                            ),
                          );
                        },
                        child: _isRegister
                            ? Column(
                                key: const ValueKey('name-field'),
                                children: [
                                  TextField(
                                    controller: _name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                        labelText: 'Your name'),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('no-name-field')),
                      ),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            iconSize: 28,
                            icon: Icon(_obscure
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: _isRegister
                            ? const SizedBox(
                                key: ValueKey('no-forgot'), height: 4)
                            : Align(
                                key: const ValueKey('forgot'),
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _openForgotPassword,
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      BigButton(
                        label: _isRegister ? 'Create account' : 'Sign in',
                        icon: _isRegister ? Icons.person_add : Icons.login,
                        loading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () =>
                            setState(() => _isRegister = !_isRegister),
                        child: Text(_isRegister
                            ? 'I already have an account'
                            : 'New here? Create an account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
