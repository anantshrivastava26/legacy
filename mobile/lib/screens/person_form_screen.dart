import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Guided, one-question-at-a-time form for adding a person.
/// Designed for elderly users: big text, one step per screen, no clutter.
class PersonFormScreen extends StatefulWidget {
  final String familyId;
  const PersonFormScreen({super.key, required this.familyId});

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  int _step = 0;
  bool _saving = false;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _nickname = TextEditingController();
  String _gender = 'UNKNOWN';
  DateTime? _dateOfBirth;
  bool _isLiving = true;
  final _birthPlace = TextEditingController();
  final _currentLocation = TextEditingController();
  final _occupation = TextEditingController();

  static const _totalSteps = 5;

  bool get _canContinue {
    if (_step == 0) {
      return _firstName.text.trim().isNotEmpty &&
          _lastName.text.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1970),
      firstDate: DateTime(1850),
      lastDate: DateTime.now(),
      helpText: 'When were they born?',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save({bool force = false}) async {
    setState(() => _saving = true);
    final api = context.read<AppState>().api;
    final body = {
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
      if (_nickname.text.trim().isNotEmpty) 'nickname': _nickname.text.trim(),
      'gender': _gender,
      if (_dateOfBirth != null)
        'dateOfBirth': _dateOfBirth!.toIso8601String(),
      'isLiving': _isLiving,
      if (_birthPlace.text.trim().isNotEmpty)
        'birthPlace': _birthPlace.text.trim(),
      if (_currentLocation.text.trim().isNotEmpty)
        'currentLocation': _currentLocation.text.trim(),
      if (_occupation.text.trim().isNotEmpty)
        'occupation': _occupation.text.trim(),
    };
    try {
      final path =
          '/api/families/${widget.familyId}/persons${force ? '?force=true' : ''}';
      await api.post(path, body);
      if (mounted) {
        showSuccess(context, '${_firstName.text.trim()} added to the family!');
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409 && e.body?['possibleDuplicate'] != null) {
        final addAnyway = await confirm(
          context,
          title: 'Already in the tree?',
          message:
              'Someone with this name already exists. Do you still want to add a new person?',
          confirmLabel: 'Add anyway',
        );
        if (addAnyway) {
          await _save(force: true);
          return;
        }
      } else {
        showError(context, e);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _StepCard(
          question: "What is this person's name?",
          child: Column(
            children: [
              TextField(
                controller: _firstName,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'First name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lastName,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nickname,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Nickname (optional)',
                    hintText: 'What does everyone call them?'),
              ),
            ],
          ),
        );
      case 1:
        return _StepCard(
          question: 'Are they male or female?',
          child: Column(
            children: [
              for (final option in const [
                ('MALE', 'Male', Icons.man),
                ('FEMALE', 'Female', Icons.woman),
                ('OTHER', 'Other', Icons.person),
                ('UNKNOWN', 'Prefer not to say', Icons.help_outline),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ChoiceTile(
                    label: option.$2,
                    icon: option.$3,
                    selected: _gender == option.$1,
                    onTap: () => setState(() => _gender = option.$1),
                  ),
                ),
            ],
          ),
        );
      case 2:
        return _StepCard(
          question: 'When were they born?',
          child: Column(
            children: [
              OutlinedButton(
                onPressed: _pickBirthDate,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cake, size: 28),
                    const SizedBox(width: 12),
                    Text(_dateOfBirth == null
                        ? 'Choose birth date'
                        : DateFormat('d MMMM yyyy').format(_dateOfBirth!)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() => _dateOfBirth = null);
                  setState(() => _step++);
                },
                child: const Text("I don't know — skip this"),
              ),
            ],
          ),
        );
      case 3:
        return _StepCard(
          question: 'Are they still with us?',
          child: Column(
            children: [
              _ChoiceTile(
                label: 'Living',
                icon: Icons.favorite,
                selected: _isLiving,
                onTap: () => setState(() => _isLiving = true),
              ),
              const SizedBox(height: 12),
              _ChoiceTile(
                label: 'Passed away',
                icon: Icons.local_florist,
                selected: !_isLiving,
                onTap: () => setState(() => _isLiving = false),
              ),
            ],
          ),
        );
      default:
        return _StepCard(
          question: 'A few more details (all optional)',
          child: Column(
            children: [
              TextField(
                controller: _birthPlace,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Born in (village / city)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _currentLocation,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Lives in'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _occupation,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Work / occupation'),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _totalSteps - 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Add a person')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: (_step + 1) / _totalSteps,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(6),
                    backgroundColor: AppColors.goldLight,
                    color: AppColors.maroon,
                  ),
                  const SizedBox(height: 8),
                  Text('Step ${_step + 1} of $_totalSteps',
                      style: const TextStyle(
                          fontSize: 16, color: AppColors.textMuted)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _stepBody(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _saving ? null : () => setState(() => _step--),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: BigButton(
                      label: isLast ? 'Finish & save' : 'Next',
                      icon: isLast ? Icons.check_circle : Icons.arrow_forward,
                      loading: _saving,
                      onPressed: _canContinue
                          ? () {
                              if (isLast) {
                                _save();
                              } else {
                                setState(() => _step++);
                              }
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String question;
  final Widget child;
  const _StepCard({required this.question, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(question,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center),
        const SizedBox(height: 28),
        child,
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.maroon : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.maroon : AppColors.gold,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 32,
                  color: selected ? Colors.white : AppColors.maroon),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textDark,
                ),
              ),
              const Spacer(),
              if (selected)
                const Icon(Icons.check_circle, color: Colors.white, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
