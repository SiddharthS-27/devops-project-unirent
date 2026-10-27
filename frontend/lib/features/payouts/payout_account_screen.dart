import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';
import 'payout_validation.dart';

final payoutAccountProvider = FutureProvider.autoDispose<PayoutAccountOut>(
  (ref) => ref.watch(apiProvider).payments.getPayoutAccount(),
);

/// Link a Razorpay account to receive rent and sale payments, and follow its
/// activation.
class PayoutAccountScreen extends ConsumerWidget {
  const PayoutAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(payoutAccountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payout account')),
      body: account.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(payoutAccountProvider),
        ),
        data: (payout) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            if (payout.status != PayoutAccountOutStatus.none) ...[
              _StatusCard(payout: payout),
              const SizedBox(height: AppSpacing.xl),
            ],
            const _HowPayoutsWork(),
            if (payout.status == PayoutAccountOutStatus.none ||
                payout.status == PayoutAccountOutStatus.suspended) ...[
              const SizedBox(height: AppSpacing.xl),
              const _LinkForm(),
            ],
          ],
        ),
      ),
    );
  }
}

class _HowPayoutsWork extends StatelessWidget {
  const _HowPayoutsWork();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How payouts work', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'When someone pays rent or buys your item by UPI, Razorpay sends the '
          'money straight to your bank account. You need a linked account '
          'before you can list anything.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Your bank details go to Razorpay through UniRent’s server. They '
          'aren’t stored by UniRent or on this phone.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends ConsumerStatefulWidget {
  const _StatusCard({required this.payout});

  final PayoutAccountOut payout;

  @override
  ConsumerState<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends ConsumerState<_StatusCard> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).payments.refreshPayoutAccount();
      ref.invalidate(payoutAccountProvider);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = StatusColors.of(context);
    final payout = widget.payout;
    final (
      IconData icon,
      Color color,
      String title,
      String message,
    ) = switch (payout.status) {
      PayoutAccountOutStatus.activated => (
        Icons.check_circle,
        status.success,
        'Ready to receive payments',
        'Rent and sale payments go straight to your bank account. You can '
            'list items now.',
      ),
      PayoutAccountOutStatus.created => (
        Icons.hourglass_top,
        status.warning,
        'Submitted to Razorpay',
        'Razorpay is setting up your account. This usually takes a few '
            'minutes.',
      ),
      PayoutAccountOutStatus.underReview => (
        Icons.manage_search,
        status.warning,
        'Under review',
        'Razorpay is checking your details. This can take up to two '
            'working days.',
      ),
      PayoutAccountOutStatus.needsClarification => (
        Icons.mark_email_unread_outlined,
        status.danger,
        'Razorpay needs more information',
        'Check your email for a message from Razorpay and reply to it, '
            'then check the status again.',
      ),
      PayoutAccountOutStatus.suspended => (
        Icons.block,
        status.danger,
        'Payouts suspended',
        'Razorpay has paused this account. Link a different account below '
            'or contact support.',
      ),
      _ => (
        Icons.help_outline,
        theme.colorScheme.onSurfaceVariant,
        'Status unavailable',
        'Check the status again in a moment.',
      ),
    };
    final updated = payout.updatedAt;
    final canRefresh = payout.status != PayoutAccountOutStatus.activated;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message),
          if (payout.razorpayAccountId case final id?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Razorpay account $id', style: theme.textTheme.bodySmall),
          ],
          if (updated != null)
            Text(
              'Updated ${formatIstDateTime(updated)}',
              style: theme.textTheme.bodySmall,
            ),
          if (canRefresh) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton.secondary(
              label: 'Check status',
              icon: Icons.refresh,
              isLoading: _refreshing,
              onPressed: _refresh,
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkForm extends ConsumerStatefulWidget {
  const _LinkForm();

  @override
  ConsumerState<_LinkForm> createState() => _LinkFormState();
}

class _LinkFormState extends ConsumerState<_LinkForm> {
  final _formKey = GlobalKey<FormState>();
  final _legalName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _account = TextEditingController();
  final _confirmAccount = TextEditingController();
  final _ifsc = TextEditingController();
  final _beneficiary = TextEditingController();
  bool _busy = false;
  String? _error;

  List<TextEditingController> get _all => [
    _legalName,
    _email,
    _phone,
    _account,
    _confirmAccount,
    _ifsc,
    _beneficiary,
  ];

  @override
  void initState() {
    super.initState();
    // Prefill what we already know; bank details are always typed.
    final me = ref.read(sessionProvider).me;
    final profile = me?.profile;
    _legalName.text = profile?.fullName ?? '';
    _beneficiary.text = profile?.fullName ?? '';
    _email.text = me?.account.email ?? '';
    final phone = profile?.phone;
    if (phone != null && phone.startsWith('+91')) {
      _phone.text = phone.substring(3);
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(apiProvider)
          .payments
          .linkPayoutAccount(
            PayoutAccountIn(
              legalName: _legalName.text.trim(),
              email: _email.text.trim(),
              phone: '+91${_phone.text}',
              accountNumber: _account.text,
              ifsc: _ifsc.text,
              beneficiaryName: _beneficiary.text.trim(),
            ),
          );
      // Don't keep bank details around any longer than needed.
      for (final c in _all) {
        c.clear();
      }
      ref.invalidate(payoutAccountProvider);
    } on Object catch (error) {
      if (mounted) setState(() => _error = friendlyMessage(error));
      if (error case ApiException(code: 'PAYOUT_ACCOUNT_EXISTS')) {
        ref.invalidate(payoutAccountProvider);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.lg);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Link your bank account',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          gap,
          if (_error != null) ...[InlineError(_error!), gap],
          AppTextField(
            controller: _legalName,
            label: 'Legal name',
            helperText: 'As on your PAN or bank records',
            textCapitalization: TextCapitalization.words,
            validator: (v) => PayoutValidators.name(v, 'Enter your legal name'),
          ),
          gap,
          AppTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            validator: PayoutValidators.email,
          ),
          gap,
          AppTextField(
            controller: _phone,
            label: 'Mobile number',
            prefixText: '+91 ',
            keyboardType: TextInputType.phone,
            inputFormatters: [...digits, LengthLimitingTextInputFormatter(10)],
            validator: PayoutValidators.mobile,
          ),
          gap,
          AppTextField(
            controller: _account,
            label: 'Bank account number',
            keyboardType: TextInputType.number,
            inputFormatters: [...digits, LengthLimitingTextInputFormatter(18)],
            validator: PayoutValidators.accountNumber,
          ),
          gap,
          AppTextField(
            controller: _confirmAccount,
            label: 'Confirm account number',
            keyboardType: TextInputType.number,
            inputFormatters: [...digits, LengthLimitingTextInputFormatter(18)],
            validator: (v) =>
                v == _account.text ? null : 'The account numbers don’t match',
          ),
          gap,
          AppTextField(
            controller: _ifsc,
            label: 'IFSC',
            hint: 'e.g. SBIN0001234',
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(11),
              TextInputFormatter.withFunction(
                (_, next) => next.copyWith(text: next.text.toUpperCase()),
              ),
            ],
            validator: PayoutValidators.ifsc,
          ),
          gap,
          AppTextField(
            controller: _beneficiary,
            label: 'Account holder name',
            helperText: 'Exactly as your bank shows it',
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                PayoutValidators.name(v, 'Enter the account holder’s name'),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Link account',
            icon: Icons.account_balance_outlined,
            isLoading: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
