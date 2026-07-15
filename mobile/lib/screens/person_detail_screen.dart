import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'add_relationship_screen.dart';

class PersonDetailScreen extends StatefulWidget {
  final String familyId;
  final String personId;
  final bool canEdit;

  const PersonDetailScreen({
    super.key,
    required this.familyId,
    required this.personId,
    required this.canEdit,
  });

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  PersonDetail? detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<AppState>().api;
      final res = await api
          .get('/api/families/${widget.familyId}/persons/${widget.personId}');
      if (mounted) setState(() => detail = PersonDetail.fromJson(res));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete() async {
    final p = detail!.person;
    final ok = await confirm(
      context,
      title: 'Delete ${p.fullName}?',
      message:
          'They will be removed from the family tree. You can undo this right after.',
    );
    if (!ok) return;
    final api = context.read<AppState>().api;
    try {
      await api.delete(
          '/api/families/${widget.familyId}/persons/${widget.personId}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${p.fullName} deleted'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: AppColors.goldLight,
            onPressed: () async {
              try {
                await api.post(
                    '/api/families/${widget.familyId}/persons/${widget.personId}/restore');
              } catch (_) {}
            },
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: AppColors.peacock),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textMuted)),
                Text(value, style: const TextStyle(fontSize: 19)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _relationSection(String title, List<Widget> chips) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: chips),
      ],
    );
  }

  Widget _personChip(Person p) {
    return ActionChip(
      avatar: PersonAvatar(
        firstName: p.firstName,
        lastName: p.lastName,
        gender: p.gender,
        radius: 14,
      ),
      label: Text(p.fullName, style: const TextStyle(fontSize: 17)),
      backgroundColor: AppColors.cream,
      side: const BorderSide(color: AppColors.gold),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PersonDetailScreen(
            familyId: widget.familyId,
            personId: p.id,
            canEdit: widget.canEdit,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final dateFmt = DateFormat('d MMMM yyyy');
    return Scaffold(
      appBar: AppBar(
        title: Text(d?.person.fullName ?? 'Loading...'),
        actions: [
          if (widget.canEdit && d != null)
            IconButton(
              iconSize: 28,
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      floatingActionButton: widget.canEdit && d != null
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddRelationshipScreen(
                    familyId: widget.familyId,
                    person: d.person,
                  ),
                ),
              ).then((_) => _load()),
              icon: const Icon(Icons.link, size: 26),
              label: const Text('Add relation'),
            )
          : null,
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                Center(
                  child: Column(
                    children: [
                      PersonAvatar(
                        firstName: d.person.firstName,
                        lastName: d.person.lastName,
                        gender: d.person.gender,
                        radius: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(d.person.fullName,
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center),
                      if (d.person.nickname != null)
                        Text('"${d.person.nickname}"',
                            style: const TextStyle(
                                fontSize: 18,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      Chip(
                        label: Text(
                          d.person.isLiving ? 'Living' : 'In loving memory',
                          style: const TextStyle(
                              fontSize: 15, color: Colors.white),
                        ),
                        backgroundColor: d.person.isLiving
                            ? AppColors.peacock
                            : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        if (d.person.dateOfBirth != null)
                          _infoRow(Icons.cake, 'Born',
                              dateFmt.format(d.person.dateOfBirth!)),
                        if (d.person.birthPlace != null)
                          _infoRow(Icons.location_city, 'Birth place',
                              d.person.birthPlace!),
                        if (d.person.currentLocation != null)
                          _infoRow(Icons.home, 'Lives in',
                              d.person.currentLocation!),
                        if (d.person.occupation != null)
                          _infoRow(
                              Icons.work, 'Occupation', d.person.occupation!),
                        if (d.person.education != null)
                          _infoRow(Icons.school, 'Education',
                              d.person.education!),
                        if (d.person.phone != null)
                          _infoRow(Icons.phone, 'Phone', d.person.phone!),
                        if (d.person.email != null)
                          _infoRow(Icons.email, 'Email', d.person.email!),
                        if (d.person.bloodGroup != null)
                          _infoRow(Icons.bloodtype, 'Blood group',
                              d.person.bloodGroup!),
                        if (d.person.religion != null)
                          _infoRow(Icons.temple_hindu, 'Religion',
                              d.person.religion!),
                      ],
                    ),
                  ),
                ),
                if (d.person.biography != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Life story',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(d.person.biography!,
                              style: const TextStyle(
                                  fontSize: 18, height: 1.5)),
                        ],
                      ),
                    ),
                  ),
                ],
                _relationSection('Parents',
                    d.parents.map((r) => _personChip(r.person)).toList()),
                _relationSection(
                    'Spouse',
                    d.spouses.map((r) => _personChip(r.person)).toList()),
                _relationSection('Children',
                    d.children.map((r) => _personChip(r.person)).toList()),
                _relationSection(
                    'Siblings', d.siblings.map(_personChip).toList()),
              ],
            ),
    );
  }
}
