import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import '../payouts/payout_gate.dart';
import 'listing_format.dart';
import 'listing_providers.dart';
import 'listing_validation.dart';
import 'photos/photo_picker.dart';
import 'photos/photo_uploader.dart';
import 'widgets/listing_photo.dart';

/// Add a listing, or edit one when [listingId] is given.
class ListingFormScreen extends ConsumerWidget {
  const ListingFormScreen({super.key, this.listingId});

  final String? listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = listingId;
    if (id == null) return const _ListingForm(initial: null);
    return ref
        .watch(listingDetailProvider(id))
        .when(
          loading: () => Scaffold(appBar: AppBar(), body: const LoadingState()),
          error: (error, _) => Scaffold(
            appBar: AppBar(),
            body: ErrorState(
              message: friendlyMessage(error),
              onRetry: () => ref.invalidate(listingDetailProvider(id)),
            ),
          ),
          data: (detail) => _ListingForm(initial: detail),
        );
  }
}

/// A photo in the form: already on the listing, or picked on this device.
class _PhotoItem {
  _PhotoItem.remote(PhotoOut this.remote) : bytes = null;
  _PhotoItem.local(Uint8List this.bytes);

  final Key key = UniqueKey();
  final Uint8List? bytes;
  PhotoOut? remote;

  /// Storage key once uploaded (new listings confirm these on create).
  String? objectKey;
  bool uploading = false;
  String? error;

  bool get ready => remote != null || objectKey != null;
}

class _ListingForm extends ConsumerStatefulWidget {
  const _ListingForm({required this.initial});

  final ListingDetail? initial;

  @override
  ConsumerState<_ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends ConsumerState<_ListingForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _serial = TextEditingController();
  final _hourly = TextEditingController();
  final _daily = TextEditingController();
  final _sale = TextEditingController();
  final _pickup = TextEditingController();

  TradeKind _kind = TradeKind.rent;
  ListingCategory? _category;
  ItemCondition? _condition;
  DateTime? _manufactureDate;
  final _photos = <_PhotoItem>[];

  bool _busy = false;
  bool _submitted = false;
  String? _error;

  ListingDetail? get _initial => widget.initial;
  bool get _isEdit => _initial != null;
  bool get _locked => _isEdit && !_initial!.canEdit;

  @override
  void initState() {
    super.initState();
    final d = _initial;
    if (d == null) return;
    String rupees(int? paise) => paise == null ? '' : '${paise ~/ 100}';
    _title.text = d.title;
    _description.text = d.description;
    _serial.text = d.asset.serialNumber ?? '';
    _hourly.text = rupees(d.pricePerHourPaise);
    _daily.text = rupees(d.pricePerDayPaise);
    _sale.text = rupees(d.salePricePaise);
    _pickup.text = d.pickupPoint;
    _kind = d.kind;
    _category = d.category == ListingCategory.unknown ? null : d.category;
    _condition = d.condition == ItemCondition.unknown ? null : d.condition;
    _manufactureDate = d.manufactureDate;
    _photos.addAll(d.photos.map(_PhotoItem.remote));
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _serial,
      _hourly,
      _daily,
      _sale,
      _pickup,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- photos ---------------------------------------------------------------

  Future<void> _addPhotos() async {
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
    final room = ListingValidators.maxPhotos - _photos.length;
    final picked = await ref.read(photoPickerProvider).pick(source, max: room);
    if (!mounted) return;
    final items = [for (final bytes in picked) _PhotoItem.local(bytes)];
    setState(() => _photos.addAll(items));
    await Future.wait(items.map(_upload));
  }

  Future<void> _upload(_PhotoItem item) async {
    setState(() {
      item
        ..uploading = true
        ..error = null;
    });
    try {
      final key = await ref.read(photoUploaderProvider).upload(item.bytes!);
      final initial = _initial;
      if (initial != null) {
        // Editing: attach to the listing right away.
        item.remote = await ref
            .read(apiProvider)
            .listings
            .addListingPhoto(initial.id, PhotoAdd(objectKey: key));
      } else {
        item.objectKey = key;
      }
    } on Object catch (error) {
      item.error = friendlyMessage(error);
    }
    if (mounted) setState(() => item.uploading = false);
  }

  Future<void> _removePhoto(_PhotoItem item) async {
    final initial = _initial;
    final remote = item.remote;
    if (initial != null && remote != null) {
      try {
        await ref
            .read(apiProvider)
            .listings
            .deleteListingPhoto(initial.id, remote.id);
      } on Object catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
        }
        return;
      }
    }
    if (mounted) setState(() => _photos.remove(item));
  }

  String? get _photoError {
    if (_isEdit) return null; // Edits change photos one at a time.
    if (_photos.any((p) => p.uploading)) {
      return 'Wait for the photos to finish uploading';
    }
    if (_photos.any((p) => p.error != null)) {
      return 'Retry or remove the photos that failed';
    }
    return ListingValidators.photoCount(_photos.length);
  }

  // ---- submit ---------------------------------------------------------------

  Future<void> _pickManufactureDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _manufactureDate ?? now,
      firstDate: DateTime(1990),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'When was it made or bought?',
    );
    if (picked != null) {
      setState(
        () => _manufactureDate = DateTime.utc(
          picked.year,
          picked.month,
          picked.day,
        ),
      );
    }
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final formValid = _formKey.currentState!.validate();
    if (!formValid || _photoError != null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final rent = _kind == TradeKind.rent;
    int? paise(TextEditingController c) =>
        ListingValidators.paiseFromRupees(c.text);
    final serial = _serial.text.trim();
    final api = ref.read(apiProvider).listings;
    final router = GoRouter.of(context);
    try {
      final initial = _initial;
      if (initial == null) {
        final created = await api.createListing(
          ListingCreate(
            kind: _kind,
            title: _title.text.trim(),
            description: _description.text.trim(),
            category: _category!,
            condition: _condition!,
            manufactureDate: _manufactureDate,
            serialNumber: serial.isEmpty ? null : serial,
            pickupPoint: _pickup.text.trim(),
            photoKeys: [for (final p in _photos) p.objectKey!],
            pricePerHourPaise: rent ? paise(_hourly) : null,
            pricePerDayPaise: rent ? paise(_daily) : null,
            salePricePaise: rent ? null : paise(_sale),
          ),
        );
        ref.invalidate(myListingsProvider);
        router.pop();
        unawaited(router.push(Routes.listing(created.id)));
      } else {
        // PATCH omits unset fields, so a price can be changed but not
        // cleared from here.
        await api.updateListing(
          initial.id,
          ListingUpdate(
            title: _title.text.trim(),
            description: _description.text.trim(),
            category: _category,
            condition: _condition,
            manufactureDate: _manufactureDate,
            serialNumber: serial.isEmpty ? null : serial,
            pickupPoint: _pickup.text.trim(),
            pricePerHourPaise: rent ? paise(_hourly) : null,
            pricePerDayPaise: rent ? paise(_daily) : null,
            salePricePaise: rent ? null : paise(_sale),
          ),
        );
        ref
          ..invalidate(listingDetailProvider(initial.id))
          ..invalidate(myListingsProvider);
        router.pop();
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'PAYOUT_ACCOUNT_REQUIRED') {
        setState(() => _busy = false);
        await showPayoutRequiredDialog(context);
      } else {
        setState(() => _error = friendlyMessage(error));
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = friendlyMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.lg);
    final theme = Theme.of(context);
    final enabled = !_locked && !_busy;
    final rent = _kind == TradeKind.rent;
    final digits = [FilteringTextInputFormatter.digitsOnly];

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit listing' : 'Add a listing')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            if (_locked) ...[
              const InlineError(
                'You can’t edit this listing while a booking is approved or '
                'active.',
              ),
              gap,
            ],
            if (_error != null) ...[InlineError(_error!), gap],
            _photoSection(theme, enabled),
            gap,
            if (_isEdit)
              Text(tradeKindLabel(_kind), style: theme.textTheme.titleSmall)
            else
              SegmentedButton<TradeKind>(
                segments: const [
                  ButtonSegment(
                    value: TradeKind.rent,
                    label: Text('Rent out'),
                    icon: Icon(Icons.autorenew),
                  ),
                  ButtonSegment(
                    value: TradeKind.sale,
                    label: Text('Sell'),
                    icon: Icon(Icons.sell_outlined),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: enabled
                    ? (s) => setState(() => _kind = s.single)
                    : null,
              ),
            gap,
            AppTextField(
              controller: _title,
              label: 'Title',
              hint: 'e.g. Canon DSLR with 18-55mm lens',
              enabled: enabled,
              textCapitalization: TextCapitalization.sentences,
              validator: ListingValidators.title,
            ),
            gap,
            AppTextField(
              controller: _description,
              label: 'Description (optional)',
              hint: 'Condition, what’s included, anything to know',
              enabled: enabled,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              validator: ListingValidators.description,
            ),
            gap,
            DropdownButtonFormField<ListingCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in listingCategories)
                  DropdownMenuItem(value: c, child: Text(categoryLabel(c))),
              ],
              onChanged: enabled ? (c) => setState(() => _category = c) : null,
              validator: (c) =>
                  ListingValidators.required(c, 'Choose a category'),
            ),
            gap,
            DropdownButtonFormField<ItemCondition>(
              initialValue: _condition,
              decoration: const InputDecoration(labelText: 'Condition'),
              items: [
                for (final c in listingConditions)
                  DropdownMenuItem(value: c, child: Text(conditionLabel(c))),
              ],
              onChanged: enabled ? (c) => setState(() => _condition = c) : null,
              validator: (c) =>
                  ListingValidators.required(c, 'Choose the condition'),
            ),
            gap,
            if (rent)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _hourly,
                      label: 'Per hour',
                      prefixText: '₹',
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      validator: ListingValidators.optionalPrice,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _daily,
                      label: 'Per day',
                      prefixText: '₹',
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      validator: (v) =>
                          ListingValidators.optionalPrice(v) ??
                          ListingValidators.rentPrices(_hourly.text, v),
                    ),
                  ),
                ],
              )
            else
              AppTextField(
                controller: _sale,
                label: 'Price',
                prefixText: '₹',
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                validator: ListingValidators.salePrice,
              ),
            gap,
            AppTextField(
              controller: _pickup,
              label: 'Pickup point',
              hint: 'e.g. Ganga Hostel gate',
              enabled: enabled,
              textCapitalization: TextCapitalization.sentences,
              validator: ListingValidators.pickupPoint,
            ),
            gap,
            Text('Item details (optional)', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled ? _pickManufactureDate : null,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _manufactureDate == null
                          ? 'Manufacture date'
                          : 'Made ${DateFormat('MMM yyyy', 'en_US').format(_manufactureDate!)}',
                    ),
                  ),
                ),
                if (_manufactureDate != null && enabled)
                  IconButton(
                    tooltip: 'Clear manufacture date',
                    onPressed: () => setState(() => _manufactureDate = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            gap,
            AppTextField(
              controller: _serial,
              label: 'Serial number',
              helperText: 'Others only see the last 4 characters',
              enabled: enabled,
              validator: ListingValidators.serialNumber,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _isEdit ? 'Save changes' : 'Publish listing',
              isLoading: _busy,
              onPressed: _locked ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoSection(ThemeData theme, bool enabled) {
    final error = _submitted ? _photoError : null;
    final canAdd = enabled && _photos.length < ListingValidators.maxPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_photos.length} of ${ListingValidators.maxPhotos} · '
          'the first photo is the cover',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in _photos)
              _PhotoTile(
                key: item.key,
                item: item,
                category: _category ?? ListingCategory.other,
                onRemove: enabled && !item.uploading
                    ? () => _removePhoto(item)
                    : null,
                onRetry: item.error == null ? null : () => _upload(item),
              ),
            if (canAdd) _AddPhotoTile(onTap: _addPhotos),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

const _tileSize = 96.0;

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    super.key,
    required this.item,
    required this.category,
    required this.onRemove,
    required this.onRetry,
  });

  final _PhotoItem item;
  final ListingCategory category;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    final bytes = item.bytes;
    final preview = item.remote != null
        ? ListingPhoto(
            url: item.remote!.url,
            category: category,
            borderRadius: radius,
          )
        : ClipRRect(
            borderRadius: radius,
            child: Image.memory(
              bytes!,
              fit: BoxFit.cover,
              width: _tileSize,
              height: _tileSize,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) =>
                  ListingPhoto(url: null, category: category),
            ),
          );
    return SizedBox.square(
      dimension: _tileSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          preview,
          if (item.uploading)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: radius,
              ),
              child: const Center(
                child: CircularProgressIndicator(semanticsLabel: 'Uploading'),
              ),
            ),
          if (item.error != null)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: radius,
              ),
              child: Center(
                child: IconButton(
                  tooltip: 'Retry upload',
                  icon: const Icon(Icons.refresh),
                  onPressed: onRetry,
                ),
              ),
            ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton.filledTonal(
                tooltip: 'Remove photo',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Add photo',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            width: _tileSize,
            height: _tileSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: scheme.outline),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: scheme.primary),
                const SizedBox(height: AppSpacing.xs),
                Text('Add photo', style: TextStyle(color: scheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
