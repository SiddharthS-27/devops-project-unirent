import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../app/routes.dart';
import '../../../ui/ui.dart';
import '../staff_format.dart';
import 'appeal_detail_screen.dart' show rulingOutcomes;
import 'appeal_providers.dart';

/// Rules on an appeal: a summary sent to both sides plus any of a charge,
/// a refund, a trust penalty, removing the listing, or a suspension or ban.
///
/// With [overrule] the admin replaces the latest ruling instead.
class RulingFormScreen extends ConsumerWidget {
  const RulingFormScreen({
    super.key,
    required this.appealId,
    this.overrule = false,
  });

  final String appealId;
  final bool overrule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(staffAppealProvider(appealId));
    return Scaffold(
      appBar: AppBar(
        title: Text(overrule ? 'Overrule' : 'Ruling'),
        leading: context.canPop()
            ? null
            : BackButton(
                onPressed: () => context.go(Routes.staffAppeal(appealId)),
              ),
      ),
      body: detail.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(staffAppealProvider(appealId)),
        ),
        data: (d) => _RulingForm(detail: d, overrule: overrule),
      ),
    );
  }
}

enum _Party { renter, owner }

class _RulingForm extends ConsumerStatefulWidget {
  const _RulingForm({required this.detail, required this.overrule});

  final AppealDetail detail;
  final bool overrule;

  @override
  ConsumerState<_RulingForm> createState() => _RulingFormState();
}

class _RulingFormState extends ConsumerState<_RulingForm> {
  final _formKey = GlobalKey<FormState>();
  final _summary = TextEditingController();
  final _charge = TextEditingController();
  final _refund = TextEditingController();
  final _points = TextEditingController(text: '10');
  bool _penalty = false;
  _Party _penaltyParty = _Party.renter;
  bool _removeListing = false;
  bool _restrict = false;
  _Party _restrictParty = _Party.renter;
  AccountRestriction _restriction = AccountRestriction.suspended;
  bool _saving = false;

  BookingOut get _booking => widget.detail.booking;

  @override
  void dispose() {
    _summary.dispose();
    _charge.dispose();
    _refund.dispose();
    _points.dispose();
    super.dispose();
  }

  String _accountOf(_Party p) =>
      p == _Party.owner ? _booking.owner.accountId : _booking.renter.accountId;

  String _partyLabel(_Party p) {
    final role = p == _Party.owner ? TradeRole.owner : TradeRole.renter;
    final profile = p == _Party.owner ? _booking.owner : _booking.renter;
    return '${profile.fullName} (${tradeRoleLabel(role, _booking.kind)})';
  }

  int? _rupees(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    return v == null ? null : v * 100;
  }

  RulingIn _ruling() => RulingIn(
    summary: _summary.text.trim(),
    chargePaise: _booking.kind == TradeKind.rent ? _rupees(_charge) : null,
    refundPaise: _rupees(_refund),
    trustPenalty: _penalty
        ? TrustPenalty(
            accountId: _accountOf(_penaltyParty),
            // An owner is penalised as a lender, a renter as a renter.
            role: _penaltyParty == _Party.owner
                ? TrustRole.lender
                : TrustRole.renter,
            points: int.parse(_points.text.trim()),
          )
        : null,
    removeListing: _removeListing,
    accountAction: _restrict
        ? AccountAction(
            accountId: _accountOf(_restrictParty),
            status: _restriction,
          )
        : null,
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ruling = _ruling();
    final outcomes = rulingOutcomes(
      RulingOut(
        id: '',
        ruledBy: '',
        ruledAt: DateTime.now(),
        summary: ruling.summary,
        chargePaise: ruling.chargePaise,
        refundPaise: ruling.refundPaise,
        trustPenalty: ruling.trustPenalty,
        removeListing: ruling.removeListing,
        accountAction: ruling.accountAction,
      ),
      _booking,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.overrule ? 'Replace the ruling?' : 'Send this ruling?',
        ),
        content: Text(
          [
            if (widget.overrule)
              'The current ruling’s penalty, suspension or ban and listing '
                  'removal are reversed. Both sides are notified.'
            else
              'Both sides are notified and the booking moves on.',
            '',
            if (outcomes.isEmpty) 'No action besides the summary.',
            for (final o in outcomes) '•  $o',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send ruling'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = widget.detail.appeal.id;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiProvider);
      await (widget.overrule
          ? api.admin.overrule(id, ruling)
          : api.staff.rule(id, ruling));
      ref
        ..invalidate(staffAppealProvider(id))
        ..invalidate(staffAppealsProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.overrule
                  ? 'New ruling sent to both sides.'
                  : 'Ruling sent to both sides.',
            ),
          ),
        );
      router.canPop() ? router.pop() : router.go(Routes.staffAppeal(id));
    } catch (error) {
      if (error is ApiException &&
          (error.code == 'APPEAL_RULED' || error.code == 'APPEAL_OPEN')) {
        ref.invalidate(staffAppealProvider(id));
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _parties(_Party value, ValueChanged<_Party> onChanged) =>
      SegmentedButton<_Party>(
        segments: [
          for (final p in _Party.values)
            ButtonSegment(value: p, label: Text(_partyLabel(p))),
        ],
        selected: {value},
        onSelectionChanged: _saving ? null : (s) => onChanged(s.single),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = _booking;
    final renter = tradeRoleLabel(TradeRole.renter, b.kind);
    const gap = SizedBox(height: AppSpacing.lg);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(b.listing.title, style: theme.textTheme.titleMedium),
            Text(
              appealReasonLabel(widget.detail.appeal.reason),
              style: theme.textTheme.bodySmall,
            ),
            if (widget.overrule) ...[
              const SizedBox(height: AppSpacing.md),
              const Text(
                'This replaces the latest ruling. Its trust penalty, '
                'suspension or ban and listing removal are reversed; a '
                'refund already paid out stays paid.',
              ),
            ],
            gap,
            AppTextField(
              controller: _summary,
              label: 'Summary',
              helperText: 'Sent to both sides',
              maxLines: 5,
              maxLength: 2000,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v?.trim().length ?? 0) < 5
                  ? 'Explain the ruling (at least 5 characters)'
                  : null,
            ),
            gap,
            if (b.kind == TradeKind.rent) ...[
              AppTextField(
                controller: _charge,
                label: 'Damage charge the renter owes',
                helperText: 'Optional. Replaces the charge recorded at return',
                prefixText: '₹',
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                enabled: !_saving,
              ),
              gap,
            ],
            AppTextField(
              controller: _refund,
              label: 'Refund to the $renter',
              helperText: 'Optional. Paid back from what they paid',
              prefixText: '₹',
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              enabled: !_saving,
              validator: (v) => (v ?? '').isNotEmpty && int.tryParse(v!) == 0
                  ? 'Leave empty for no refund'
                  : null,
            ),
            gap,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Trust penalty'),
              value: _penalty,
              onChanged: _saving ? null : (v) => setState(() => _penalty = v),
            ),
            if (_penalty) ...[
              _parties(_penaltyParty, (p) => setState(() => _penaltyParty = p)),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _points,
                label: 'Points',
                helperText: '1 to 50 points off their trust score',
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                enabled: !_saving,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 1 || n > 50
                      ? 'Enter 1 to 50 points'
                      : null;
                },
              ),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remove the listing'),
              value: _removeListing,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _removeListing = v ?? false),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Suspend or ban an account'),
              value: _restrict,
              onChanged: _saving ? null : (v) => setState(() => _restrict = v),
            ),
            if (_restrict) ...[
              _parties(
                _restrictParty,
                (p) => setState(() => _restrictParty = p),
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<AccountRestriction>(
                segments: const [
                  ButtonSegment(
                    value: AccountRestriction.suspended,
                    label: Text('Suspend'),
                  ),
                  ButtonSegment(
                    value: AccountRestriction.banned,
                    label: Text('Ban'),
                  ),
                ],
                selected: {_restriction},
                onSelectionChanged: _saving
                    ? null
                    : (s) => setState(() => _restriction = s.single),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _restriction == AccountRestriction.banned
                    ? 'A banned account can’t sign in.'
                    : 'A suspended account can’t list, request or pay, but '
                          'can finish open handovers.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton.primary(
              label: 'Send ruling',
              isLoading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
