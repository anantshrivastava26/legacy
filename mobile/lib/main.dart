import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/families_screen.dart';
import 'theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const FamilyTreeApp(),
    ),
  );
}

class FamilyTreeApp extends StatelessWidget {
  const FamilyTreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Tree',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.initializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.family_restroom, size: 88, color: AppColors.maroon),
              SizedBox(height: 20),
              Text('Family Tree',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.maroon)),
              SizedBox(height: 30),
              CircularProgressIndicator(color: AppColors.gold),
            ],
          ),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: state.isLoggedIn
          ? const FamiliesScreen(key: ValueKey('families'))
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}
