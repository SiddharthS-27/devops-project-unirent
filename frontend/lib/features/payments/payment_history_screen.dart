import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import '../bookings/booking_format.dart';
import '../bookings/booking_providers.dart';

/// Every payment you made or received, with refunds, newest first.
class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  final _items = <PaymentHistoryItem>[];
  String? _cursor;
  bool _done = false;
  bool _loading = false;
  Object? _error;
  String? _marking;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _cursor = null;
      _done = false;
      _error = null;
    });
    await _load();
  }

  Future<void> _load() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(apiProvider)
          .payments
          .paymentHistory(cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRefundDone(RefundOut refund) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark refund handed back?'),
        content: Text(
          'Only confirm once you’ve given ${formatMoney(refund.amountPaise)} '
          'back in cash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I handed it back'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _marking = refund.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).payments.markCashRefunded(refund.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Refund marked as done')));
      await _reload();
    } on Object catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
    } finally {
      if (mounted) setState(() => _marking = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_items.isEmpty && _error != null) {
      body = ErrorState(message: friendlyMessage(_error!), onRetry: _reload);
    } else if (_items.isEmpty && !_done) {
      body = const LoadingState();
    } else if (_items.isEmpty) {
      body = const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No payments yet',
        message: 'Rent, purchases and refunds show up here.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _PaymentCard(
                  item: item,
                  marking: _marking,
                  onMarkRefund: _markRefundDone,
                ),
              ),
            if (!_done)
              Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: _load,
                        child: Text(
                          _error == null ? 'Show more' : 'Couldn’t load. Retry',
                        ),
                      ),
              ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Payment history')),
      body: body,
    );
  }
}

String refundStatusLabel(RefundOutStatus status, {required bool payee}) =>
    switch (status) {
      RefundOutStatus.pending => 'Processing',
      RefundOutStatus.processed => 'Refunded',
      RefundOutStatus.failed => 'Failed',
      RefundOutStatus.cashPending =>
        payee ? 'To hand back in cash' : 'The owner hands it back in cash',
      RefundOutStatus.cashDone => 'Handed back in cash',
      RefundOutStatus.unknown => 'Updated',
    };

class _PaymentCard extends ConsumerWidget {
  const _PaymentCard({
    required this.item,
    required this.marking,
    required this.onMarkRefund,
  });

  final PaymentHistoryItem item;
  final String? marking;
  final ValueChanged<RefundOut> onMarkRefund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = StatusColors.of(context);
    final paid = item.direction == Direction.paid;
    final name = ref
        .watch(profileViewProvider(item.counterpartyId))
        .value
        ?.fullName;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return AppCard(
      onTap: () => context.push(Routes.booking(item.bookingId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                paid ? Icons.arrow_upward : Icons.arrow_downward,
                color: paid ? theme.colorScheme.onSurface : status.success,
                semanticLabel: paid ? 'Paid' : 'Received',
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${paymentPurposeLabel(item.purpose)} · '
                  '${paid ? 'to' : 'from'} ${name ?? '…'}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                '${paid ? '−' : '+'}${formatMoney(item.amountPaise)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: paid ? null : status.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              if (item.method == PaymentMethod.cash) 'Cash' else 'UPI',
              paymentStatusLabel(item.status),
              formatIstDateTime(item.capturedAt ?? item.createdAt),
            ].join(' · '),
            style: muted,
          ),
          if (item.items.length > 1)
            for (final line in item.items)
              Text(
                '${line.label}: ${formatMoney(line.amountPaise)}',
                style: muted,
              ),
          for (final refund in item.refunds) ...[
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                const Icon(Icons.undo, size: AppSizes.iconSm),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Refund ${formatMoney(refund.amountPaise)} · '
                    '${refundStatusLabel(refund.status, payee: !paid)}',
                  ),
                ),
              ],
            ),
            if (!paid && refund.status == RefundOutStatus.cashPending)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: marking == null
                      ? () => onMarkRefund(refund)
                      : null,
                  child: const Text('Mark refund handed back'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
