import 'package:flutter/material.dart';
import 'package:ridema_core/ridema_core.dart';

import '../l10n/driver_strings.dart';

/// Today / last 7 days: trips and cash collected (informational, 0 % commission).
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  late Future<Json> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = CoreServices.of(context).api.earnings(days: 7);
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l.earningsTitle)),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              ErrorBanner(errorText(l, snap.error!)),
              gap16,
              SecondaryButton(
                label: l.retry,
                onPressed: () => setState(() => _future = CoreServices.of(context).api.earnings(days: 7)),
              ),
            ]);
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final j = snap.data!;
          final days = (j['days'] is List ? j['days'] as List : const []).whereType<Map>().toList();
          final today = days.where((d) => d['day'] == _today()).firstOrNull;
          final total = j['total'] is Map ? j['total'] as Map : const {};
          Widget tile(String title, int trips, int cash, Key key) => Card(
                key: key,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    gap8,
                    Text(l.earningsCash(cash), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    Text(l.earningsTrips(trips)),
                  ]),
                ),
              );
          return ListView(padding: const EdgeInsets.all(16), children: [
            tile(l.earningsToday, _int(today?['trips']), _int(today?['cash']), const ValueKey('earnings_today')),
            tile(l.earningsWeek, _int(total['trips']), _int(total['cash']), const ValueKey('earnings_week')),
            InfoBox(l.earningsNoCommission),
            gap16,
            if (days.isEmpty) Text(context.ds.earningsEmpty, textAlign: TextAlign.center),
            for (final d in days)
              ListTile(
                title: Text(formatDate(lang, DateTime.tryParse('${d['day']}'))),
                subtitle: Text(l.earningsTrips(_int(d['trips']))),
                trailing: Text(l.priceDh(_int(d['cash'])), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
          ]);
        },
      ),
    );
  }
}
