import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';
import '../listings/photos/photo_picker.dart';
import '../listings/photos/photo_uploader.dart';
import '../profile/widgets/profile_avatar.dart';
import 'onboarding_scaffold.dart';
import 'profile_validation.dart';

/// The profile form (`PUT /me/profile`): onboarding step 1, or editing
/// from the Profile tab when [editing].
class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key, this.editing = false});

  final bool editing;

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

  /// Saved photo key, or the key of a newly uploaded photo.
  String? _photoKey;
  String? _photoUrl;
  Uint8List? _photoBytes;
  bool _uploadingPhoto = false;

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
      _photoKey = profile.photoKey;
      _photoUrl = profile.photoUrl;
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

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await ref.read(photoPickerProvider).pick(source, max: 1);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _photoBytes = picked.single;
      _uploadingPhoto = true;
      _error = null;
    });
    try {
      final key = await ref
          .read(photoUploaderProvider)
          .upload(picked.single, purpose: UploadPurpose.profile);
      if (mounted) setState(() => _photoKey = key);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _photoBytes = null;
          _error = friendlyMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _uploadingPhoto) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Captured before awaiting: this screen may be gone afterwards.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
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
              photoKey: _photoKey,
            ),
          );
      if (widget.editing) {
        // Leave first: a session change re-applies the current routes, which
        // would undo a pop made after it.
        router.pop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
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
    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PhotoSlot(
            name: _fullName.text,
            photoUrl: _photoUrl,
            bytes: _photoBytes,
            uploading: _uploadingPhoto,
            onPick: _busy ? null : _pickPhoto,
          ),
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
            isExpanded: true,
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
            label: widget.editing ? 'Save changes' : 'Save and continue',
            isLoading: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
    if (widget.editing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [form],
        ),
      );
    }
    return OnboardingScaffold(
      step: OnboardingStep.profile,
      title: 'Your profile',
      children: [form],
    );
  }
}

/// The profile photo with a button to add or change it.
class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.name,
    required this.photoUrl,
    required this.bytes,
    required this.uploading,
    required this.onPick,
  });

  final String name;
  final String? photoUrl;
  final Uint8List? bytes;
  final bool uploading;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null || bytes != null;
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            ProfileAvatar(
              name: name,
              photoUrl: photoUrl,
              bytes: bytes,
              radius: 32,
            ),
            if (uploading)
              const SizedBox.square(
                dimension: 64,
                child: CircularProgressIndicator(semanticsLabel: 'Uploading'),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: uploading ? null : onPick,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(hasPhoto ? 'Change photo' : 'Add photo (optional)'),
            ),
          ),
        ),
      ],
    );
  }
}
