import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ActivityScreen extends StatefulWidget {
  final String familyId;
  const ActivityScreen({super.key, required this.familyId});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<ActivityItem> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<AppState>().api;
      final res =
          await api.get('/api/families/${widget.familyId}/activity');
      if (mounted) {
        setState(() {
          items = (res['activities'] as List)
              .map((e) => ActivityItem.fromJson(e))
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

  IconData _icon(String action) => switch (action) {
        'PERSON_ADDED' => Icons.person_add,
        'PERSON_UPDATED' => Icons.edit,
        'PERSON_DELETED' => Icons.person_remove,
        'PERSON_RESTORED' => Icons.restore,
        'RELATIONSHIP_ADDED' => Icons.link,
        'RELATIONSHIP_REMOVED' => Icons.link_off,
        'MEMBER_JOINED' => Icons.group_add,
        'FAMILY_CREATED' => Icons.celebration,
        _ => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy, h:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('Recent activity')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(
                  child: Text('Nothing has happened yet',
                      style: TextStyle(
                          fontSize: 19, color: AppColors.textMuted)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final a = items[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                AppColors.peacock.withOpacity(0.12),
                            child: Icon(_icon(a.action),
                                color: AppColors.peacock, size: 26),
                          ),
                          title: Text(a.summary,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(fmt.format(a.at.toLocal())),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
