import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Simple language: "How is this person related?" instead of
/// "Genealogical relationship".
class AddRelationshipScreen extends StatefulWidget {
  final String familyId;
  final Person person;

  const AddRelationshipScreen(
      {super.key, required this.familyId, required this.person});

  @override
  State<AddRelationshipScreen> createState() => _AddRelationshipScreenState();
}

class _AddRelationshipScreenState extends State<AddRelationshipScreen> {
  List<Person> others = [];
  Person? selected;
  String? relation;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<AppState>().api;
      final res = await api.get('/api/families/${widget.familyId}/persons');
      if (mounted) {
        setState(() {
          others = (res['persons'] as List)
              .map((e) => Person.fromJson(e))
              .where((p) => p.id != widget.person.id)
              .toList();
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _save() async {
    if (selected == null || relation == null) return;
    setState(() => _saving = true);
    final api = context.read<AppState>().api;

    // Translate friendly choice into API relationship
    late String type;
    late String fromId;
    late String toId;
    switch (relation!) {
      case 'PARENT_OF':
        type = 'PARENT';
        fromId = selected!.id;
        toId = widget.person.id;
        break;
      case 'CHILD_OF':
        type = 'PARENT';
        fromId = widget.person.id;
        toId = selected!.id;
        break;
      case 'ADOPTED_CHILD_OF':
        type = 'ADOPTED_PARENT';
        fromId = widget.person.id;
        toId = selected!.id;
        break;
      case 'FOSTER_PARENT_OF':
        type = 'FOSTER_PARENT';
        fromId = selected!.id;
        toId = widget.person.id;
        break;
      default:
        type = 'SPOUSE';
        fromId = widget.person.id;
        toId = selected!.id;
    }

    try {
      await api.post('/api/families/${widget.familyId}/relationships', {
        'type': type,
        'fromPersonId': fromId,
        'toPersonId': toId,
      });
      if (mounted) {
        showSuccess(context, 'Relationship saved!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.person.firstName;
    final choices = [
      ('PARENT_OF', 'Their parent', Icons.escalator_warning),
      ('CHILD_OF', 'Their child', Icons.child_care),
      ('SPOUSE_OF', 'Their husband / wife', Icons.favorite),
      ('ADOPTED_CHILD_OF', 'Their adopted child', Icons.volunteer_activism),
      ('FOSTER_PARENT_OF', 'Their foster parent', Icons.night_shelter),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Relate someone to $name')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('1. Choose the person',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (others.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No one else in the tree yet. Add another person first.',
                  style: TextStyle(fontSize: 18, color: AppColors.textMuted),
                ),
              ),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in others)
                ChoiceChip(
                  avatar: selected?.id == p.id
                      ? null
                      : PersonAvatar(
                          firstName: p.firstName,
                          lastName: p.lastName,
                          gender: p.gender,
                          radius: 13,
                        ),
                  label: Text(p.fullName,
                      style: TextStyle(
                          fontSize: 17,
                          color: selected?.id == p.id
                              ? Colors.white
                              : AppColors.textDark)),
                  selected: selected?.id == p.id,
                  selectedColor: AppColors.maroon,
                  backgroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  onSelected: (_) => setState(() => selected = p),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text('2. How are they related to $name?',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final c in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: relation == c.$1 ? AppColors.peacock : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => relation = c.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: relation == c.$1
                              ? AppColors.peacock
                              : AppColors.gold,
                          width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(c.$3,
                            size: 30,
                            color: relation == c.$1
                                ? Colors.white
                                : AppColors.peacock),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            selected == null
                                ? c.$2
                                : '${selected!.firstName} is ${c.$2.toLowerCase()}',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: relation == c.$1
                                  ? Colors.white
                                  : AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          BigButton(
            label: 'Save relationship',
            icon: Icons.check_circle,
            loading: _saving,
            onPressed: selected != null && relation != null ? _save : null,
          ),
        ],
      ),
    );
  }
}
