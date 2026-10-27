import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';
import 'onboarding_scaffold.dart';
import 'profile_validation.dart';

/// Onboarding step 1: the profile (`PUT /me/profile`).
class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _rollNumber = TextEditingController();
  final _department = TextEditingController();
  final _hostelName = TextEditingController();
  final _roomNumber = TextEditingController();
  final _homeAddress = TextEditingController();
  int? _year;
  ResidenceType _residence = ResidenceType.hostel;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Prefill when editing an existing profile.
    final profile = ref.read(sessionProvider).me?.profile;
    if (profile != null) {
      _fullName.text = profile.fullName;
      _rollNumber.text = profile.rollNumber;
      _department.text = profile.department;
      _year = profile.year;
      _residence = profile.residence.type == ResidenceType.dayScholar
          ? ResidenceType.dayScholar
          : ResidenceType.hostel;
      _hostelName.text = profile.residence.hostelName ?? '';
      _roomNumber.text = profile.residence.roomNumber ?? '';
      _homeAddress.text = profile.residence.homeAddress ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _rollNumber,
      _department,
      _hostelName,
      _roomNumber,
      _homeAddress,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isHostel => _residence == ResidenceType.hostel;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(apiProvider)
          .profiles
          .putProfile(
            ProfileIn(
              fullName: _fullName.text.trim(),
              rollNumber: _rollNumber.text.trim(),
              department: _department.text.trim(),
              year: _year!,
              residenceType: _residence,
              hostelName: _isHostel ? _hostelName.text.trim() : null,
              roomNumber: _isHostel ? _roomNumber.text.trim() : null,
              homeAddress: _isHostel ? null : _homeAddress.text.trim(),
            ),
          );
      await ref.read(sessionProvider.notifier).refreshMe();
    } on Object catch (error) {
      if (mounted) setState(() => _error = friendlyMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.lg);
    return OnboardingScaffold(
      step: OnboardingStep.profile,
      title: 'Your profile',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PhotoSlot(),
              gap,
              if (_error != null) ...[InlineError(_error!), gap],
              AppTextField(
                controller: _fullName,
                label: 'Full name',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: ProfileValidators.fullName,
              ),
              gap,
              AppTextField(
                controller: _rollNumber,
                label: 'Roll number',
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                validator: ProfileValidators.rollNumber,
              ),
              gap,
              AppTextField(
                controller: _department,
                label: 'Department',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: ProfileValidators.department,
              ),
              gap,
              DropdownButtonFormField<int>(
                initialValue: _year,
                decoration: const InputDecoration(labelText: 'Year of study'),
                items: [
                  for (var year = 1; year <= 6; year++)
                    DropdownMenuItem(value: year, child: Text('Year $year')),
                ],
                onChanged: (value) => setState(() => _year = value),
                validator: ProfileValidators.year,
              ),
              gap,
              Text(
                'Where do you stay?',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<ResidenceType>(
                segments: const [
                  ButtonSegment(
                    value: ResidenceType.hostel,
                    label: Text('Hostel'),
                    icon: Icon(Icons.apartment_outlined),
                  ),
                  ButtonSegment(
                    value: ResidenceType.dayScholar,
                    label: Text('Day scholar'),
                    icon: Icon(Icons.home_outlined),
                  ),
                ],
                selected: {_residence},
                onSelectionChanged: (selection) =>
                    setState(() => _residence = selection.single),
              ),
              gap,
              if (_isHostel) ...[
                AppTextField(
                  controller: _hostelName,
                  label: 'Hostel name',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: ProfileValidators.hostelName,
                ),
                gap,
                AppTextField(
                  controller: _roomNumber,
                  label: 'Room number',
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  validator: ProfileValidators.roomNumber,
                ),
              ] else
                AppTextField(
                  controller: _homeAddress,
                  label: 'Home address',
                  helperText: 'Only shown to people you trade with',
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  autofillHints: const [AutofillHints.fullStreetAddress],
                  validator: ProfileValidators.homeAddress,
                ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Save and continue',
                isLoading: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Placeholder until photo uploads are live.
class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: scheme.surfaceContainerHighest,
          child: Icon(Icons.person_outline, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: AppSpacing.lg),
        const Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: null,
              child: Text('Add photo (coming soon)'),
            ),
          ),
        ),
      ],
    );
  }
}
