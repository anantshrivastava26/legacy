import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'person_detail_screen.dart';
import 'person_form_screen.dart';

class PeopleScreen extends StatefulWidget {
  final String familyId;
  final bool canEdit;
  const PeopleScreen(
      {super.key, required this.familyId, required this.canEdit});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  List<Person> persons = [];
  bool loading = true;
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = context.read<AppState>().api;
      final res = await api.get(
          '/api/families/${widget.familyId}/persons?q=${Uri.encodeQueryComponent(_query)}');
      if (mounted) {
        setState(() {
          persons =
              (res['persons'] as List).map((e) => Person.fromJson(e)).toList();
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

  void _onSearch(String value) {
    _query = value.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PersonFormScreen(familyId: widget.familyId)),
              ).then((_) => _load()),
              icon: const Icon(Icons.person_add, size: 28),
              label: const Text('Add person'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: 'Search by name, city, work...',
                prefixIcon: Icon(Icons.search, size: 30),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : persons.isEmpty
                    ? const Center(
                        child: Text('No people found',
                            style: TextStyle(
                                fontSize: 19, color: AppColors.textMuted)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        itemCount: persons.length,
                        itemBuilder: (context, i) {
                          final p = persons[i];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 6),
                              leading: PersonAvatar(
                                firstName: p.firstName,
                                lastName: p.lastName,
                                gender: p.gender,
                              ),
                              title: Text(p.fullName),
                              subtitle: Text([
                                p.lifeSpan,
                                if (p.currentLocation != null)
                                  p.currentLocation!,
                              ].join(' · ')),
                              trailing:
                                  const Icon(Icons.chevron_right, size: 32),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PersonDetailScreen(
                                    familyId: widget.familyId,
                                    personId: p.id,
                                    canEdit: widget.canEdit,
                                  ),
                                ),
                              ).then((_) => _load()),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
