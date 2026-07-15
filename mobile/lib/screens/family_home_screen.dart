import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'people_screen.dart';
import 'person_form_screen.dart';
import 'tree_screen.dart';
import 'activity_screen.dart';
import 'members_screen.dart';

class FamilyHomeScreen extends StatefulWidget {
  final String familyId;
  const FamilyHomeScreen({super.key, required this.familyId});

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  FamilySummary? family;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<AppState>().api;
      final res = await api.get('/api/families/${widget.familyId}');
      if (mounted) {
        setState(() => family = FamilySummary.fromJson(res['family']));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _showInvite() {
    final code = family?.inviteCode;
    if (code == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite your family'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with family members so they can join:'),
            const SizedBox(height: 18),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.goldLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: AppColors.maroonDark,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              showSuccess(context, 'Code copied! Share it on WhatsApp or SMS.');
            },
            child: const Text('Copy code'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = family;
    return Scaffold(
      appBar: AppBar(title: Text(f?.name ?? 'Loading...')),
      body: f == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (f.description != null && f.description!.isNotEmpty) ...[
                  Text(f.description!,
                      style: const TextStyle(
                          fontSize: 17, color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                ],
                BigMenuTile(
                  title: 'Family Tree',
                  subtitle: 'See everyone in one picture',
                  icon: Icons.account_tree,
                  iconColor: AppColors.peacock,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TreeScreen(familyId: f.id)),
                  ),
                ),
                BigMenuTile(
                  title: 'People',
                  subtitle: '${f.personCount} people · search & view details',
                  icon: Icons.people,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            PeopleScreen(familyId: f.id, canEdit: f.canEdit)),
                  ).then((_) => _load()),
                ),
                if (f.canEdit)
                  BigMenuTile(
                    title: 'Add a person',
                    subtitle: 'Step-by-step, takes under a minute',
                    icon: Icons.person_add,
                    iconColor: AppColors.gold,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PersonFormScreen(familyId: f.id)),
                    ).then((_) => _load()),
                  ),
                BigMenuTile(
                  title: 'Recent activity',
                  subtitle: 'Who added or changed what',
                  icon: Icons.history,
                  iconColor: AppColors.textMuted,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ActivityScreen(familyId: f.id)),
                  ),
                ),
                BigMenuTile(
                  title: 'Members',
                  subtitle: '${f.memberCount} family members using the app',
                  icon: Icons.manage_accounts,
                  iconColor: AppColors.maroonDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MembersScreen(
                            familyId: f.id, isAdmin: f.isAdmin)),
                  ),
                ),
                const SizedBox(height: 20),
                if (f.isAdmin && f.inviteCode != null)
                  BigButton(
                    label: 'Invite family members',
                    icon: Icons.card_giftcard,
                    color: AppColors.peacock,
                    onPressed: _showInvite,
                  ),
              ],
            ),
    );
  }
}
