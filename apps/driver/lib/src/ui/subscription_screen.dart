import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';

/// Subscription (only when `subscriptions_enabled`): status, rides today vs
/// free limit, pay by cash code (CashPlus / Wafacash), card or wallet (D13, D14).
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Json? _data;
  Object? _error;
  Json? _instructions;
  String? _busyMethod;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await CoreServices.of(context).api.subscription();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pay(String method) async {
    setState(() => _busyMethod = method);
    try {
      final r = await CoreServices.of(context).api.subscribe(method);
      if (!mounted) return;
      setState(() => _instructions = r['instructions'] is Map ? Json.from(r['instructions'] as Map) : null);
      await _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busyMethod = null);
    }
  }

  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  String _methodLabel(AppLocalizations l, String m) => switch (m) {
        'cashplus' => l.payCashplus,
        'wafacash' => l.payWafacash,
        'card' => l.payCard,
        'wallet' => l.payWallet,
        _ => m,
      };

  Widget _instructionsBox(AppLocalizations l, Json i) {
    if (i['kind'] == 'cash_code') {
      return InfoBox(
        l.subscriptionCashCode('${i['agent'] ?? ''}', _int(i['amount']), '${i['code'] ?? ''}', _int(i['valid_hours'])),
        icon: Icons.storefront,
        color: BrandColors.accent,
      );
    }
    final url = '${i['url'] ?? ''}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (i['note'] != null) InfoBox('${i['note']}'),
      if (url.isNotEmpty)
        SecondaryButton(
          label: l.subscriptionOpenPayment,
          icon: Icons.open_in_new,
          onPressed: () => CoreServices.of(context).launcher.openUrl(Uri.parse(url)),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: Text(l.subscriptionTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_error != null) ...[ErrorBanner(errorText(l, _error!)), gap8, SecondaryButton(label: l.retry, onPressed: _load)],
          if (d == null && _error == null) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          if (d != null && d['enabled'] != true) InfoBox(l.subscriptionOff),
          if (d != null && d['enabled'] == true) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['active'] == true ? l.subscriptionActive : l.subscriptionInactive,
                      key: const ValueKey('subscription_status'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  gap8,
                  Text(l.subscriptionPrice(_int(d['price']), _int(d['period_days']))),
                  Text(l.subscriptionFreeRides(_int(d['free_rides_per_day']))),
                  Text(l.subscriptionRidesToday(_int(d['rides_today']), _int(d['free_rides_per_day'])),
                      key: const ValueKey('subscription_rides_today'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            if (_instructions != null) ...[gap8, _instructionsBox(l, _instructions!)],
            for (final p in (d['pending'] is List ? d['pending'] as List : const []).whereType<Map>())
              if (p['instructions'] is Map) ...[
                gap8,
                Text(l.subscriptionPending, style: const TextStyle(fontWeight: FontWeight.w700)),
                _instructionsBox(l, Json.from(p['instructions'] as Map)),
              ],
            if (d['active'] != true) ...[
              gap16,
              Text(l.subscriptionPayWith, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              for (final m in (d['methods'] is List ? d['methods'] as List : const []).whereType<Map>())
                ListTile(
                  key: ValueKey('pay_${m['method']}'),
                  title: Text(_methodLabel(l, '${m['method']}')),
                  subtitle: m['available'] == false ? Text(l.payUnavailable) : null,
                  enabled: m['available'] != false && _busyMethod == null,
                  trailing: _busyMethod == m['method']
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: () => _pay('${m['method']}'),
                ),
            ],
          ],
        ]),
      ),
    );
  }
}
