import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class MembersScreen extends StatefulWidget {
  final String familyId;
  final bool isAdmin;
  const MembersScreen(
      {super.key, required this.familyId, required this.isAdmin});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<FamilyMemberItem> members = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<AppState>().api;
      final res = await api.get('/api/families/${widget.familyId}/members');
      if (mounted) {
        setState(() {
          members = (res['members'] as List)
              .map((e) => FamilyMemberItem.fromJson(e))
              .toList();
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showError(context, e);
      }
    }
  }

  String _roleLabel(String role) => switch (role) {
        'OWNER' => 'Owner',
        'ADMIN' => 'Admin',
        'CONTRIBUTOR' => 'Contributor',
        _ => 'Viewer',
      };

  Future<void> _changeRole(FamilyMemberItem m) async {
    final role = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Change role for ${m.displayName}'),
        children: [
          for (final r in const ['ADMIN', 'CONTRIBUTOR', 'VIEWER'])
            SimpleDialogOption(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(_roleLabel(r), style: const TextStyle(fontSize: 19)),
            ),
        ],
      ),
    );
    if (role == null) return;
    try {
      final api = context.read<AppState>().api;
      await api.patch(
          '/api/families/${widget.familyId}/members/${m.userId}',
          {'role': role});
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family members')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: members.length,
              itemBuilder: (context, i) {
                final m = members[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: m.role == 'OWNER'
                          ? AppColors.gold
                          : AppColors.peacock,
                      child: Text(
                        m.displayName.isNotEmpty
                            ? m.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(m.displayName),
                    subtitle: Text(_roleLabel(m.role)),
                    trailing: widget.isAdmin && m.role != 'OWNER'
                        ? IconButton(
                            iconSize: 28,
                            tooltip: 'Change role',
                            icon: const Icon(Icons.admin_panel_settings,
                                color: AppColors.maroon),
                            onPressed: () => _changeRole(m),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
