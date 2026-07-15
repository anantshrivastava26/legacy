import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'family_home_screen.dart';

class FamiliesScreen extends StatelessWidget {
  const FamiliesScreen({super.key});

  Future<void> _createFamily(BuildContext context) async {
    final state = context.read<AppState>();
    final name = TextEditingController();
    final description = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create a family'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Family name', hintText: 'e.g. Sharma Family'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: description,
              decoration:
                  const InputDecoration(labelText: 'About (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (created != true || name.text.trim().isEmpty) return;
    try {
      await state.createFamily(name.text.trim(), description.text.trim());
      if (context.mounted) showSuccess(context, 'Family created!');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _joinFamily(BuildContext context) async {
    final state = context.read<AppState>();
    final code = TextEditingController();
    final joined = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join a family'),
        content: TextField(
          controller: code,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
              labelText: 'Invite code',
              hintText: 'Ask a family member for the code'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Join')),
        ],
      ),
    );
    if (joined != true || code.text.trim().isEmpty) return;
    try {
      await state.joinFamily(code.text.trim().toUpperCase());
      if (context.mounted) showSuccess(context, 'Welcome to the family!');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Families'),
        actions: [
          IconButton(
            iconSize: 30,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await confirm(context,
                  title: 'Sign out?',
                  message: 'You can sign back in any time.',
                  confirmLabel: 'Sign out');
              if (ok) state.logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.refreshFamilies,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Namaste, ${state.user?.displayName ?? ''}!',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            const Text('Choose a family to open, or start a new one.',
                style: TextStyle(fontSize: 17, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            if (state.families.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Icon(Icons.park_outlined,
                          size: 64, color: AppColors.gold),
                      const SizedBox(height: 12),
                      Text('No families yet',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text(
                        'Create your family tree or join one with an invite code.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 17, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            for (final family in state.families)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  leading: const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.maroon,
                    child: Icon(Icons.home, color: Colors.white, size: 30),
                  ),
                  title: Text(family.name),
                  subtitle: Text(
                      '${family.personCount} people · ${family.memberCount} members · ${family.myRole.toLowerCase()}'),
                  trailing: const Icon(Icons.chevron_right, size: 32),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FamilyHomeScreen(familyId: family.id)),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            BigButton(
              label: 'Create a new family',
              icon: Icons.add_home,
              onPressed: () => _createFamily(context),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => _joinFamily(context),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_add, size: 28),
                  SizedBox(width: 12),
                  Text('Join with invite code'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
