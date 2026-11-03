import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ridema_core/ridema_core.dart';

import '../l10n/driver_strings.dart';

typedef LoadEarnings = Future<DriverEarnings> Function({String? month});
typedef SaveGoal = Future<void> Function(int? amount);

/// Income (informational, 0 % commission, D82): today + last 7 days, or one
/// calendar month (earlier months with ‹ ›), and an optional daily goal.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key, this.load, this.saveGoal});

  /// Overrides for tests; default to the API.
  final LoadEarnings? load;
  final SaveGoal? saveGoal;

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Future<DriverEarnings>? _future;
  bool _monthView = false;

  /// `YYYY-MM` shown in the month view; null = this month.
  String? _month;

  LoadEarnings get _load => widget.load ?? ({String? month}) => CoreServices.of(context).api.driverEarnings(month: month);
  SaveGoal get _saveGoal => widget.saveGoal ?? CoreServices.of(context).api.setDailyGoal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load(month: _month);
  }

  void _reload() {
    final f = _load(month: _month);
    setState(() {
      _future = f;
    });
  }

  void _shiftMonth(String current, int by) {
    final d = DateTime.tryParse('$current-01');
    if (d == null) return;
    final m = DateTime(d.year, d.month + by);
    _month = '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
    _reload();
  }

  Future<void> _editGoal(int? current) async {
    final ds = context.ds;
    final l = context.l10n;
    // Not disposed here: the dialog still uses it during its closing animation.
    final ctl = TextEditingController(text: current?.toString() ?? '');
    String? error;
    // null = dialog dismissed; -1 = remove the goal.
    final res = await showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(ds.goalTitle),
          content: TextField(
            key: const ValueKey('goal_amount'),
            controller: ctl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: ds.goalHint, suffixText: 'DH', errorText: error),
          ),
          actions: [
            if (current != null) TextButton(onPressed: () => Navigator.pop(c, -1), child: Text(ds.goalRemove)),
            TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
            FilledButton(
              key: const ValueKey('goal_save'),
              onPressed: () {
                final v = int.tryParse(ctl.text.trim());
                if (v == null || v < 10 || v > 5000) {
                  setD(() => error = ds.goalInvalid);
                  return;
                }
                Navigator.pop(c, v);
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    if (res == null || !mounted) return;
    try {
      await _saveGoal(res == -1 ? null : res);
      _reload();
    } catch (e) {
      if (mounted) showInfoSnack(context, ds.error(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ds = context.ds;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l.earningsTitle)),
      body: FutureBuilder<DriverEarnings>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              ErrorBanner(errorText(l, snap.error!)),
              gap16,
              SecondaryButton(label: l.retry, onPressed: _reload),
            ]);
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final e = snap.data!;
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
          final days = _monthView ? e.monthDays : e.days;
          final monthDate = DateTime.tryParse('${e.month}-01');
          final monthName = monthDate == null ? e.month : DateFormat.yMMMM(lang).format(monthDate);
          return ListView(padding: const EdgeInsets.all(16), children: [
            GoalCard(earnings: e, onEdit: () => _editGoal(e.goal)),
            gap8,
            SegmentedButton<bool>(
              key: const ValueKey('earnings_period'),
              segments: [
                ButtonSegment(value: false, label: Text(l.earningsWeek)),
                ButtonSegment(value: true, label: Text(ds.earningsMonthTab)),
              ],
              selected: {_monthView},
              onSelectionChanged: (v) => setState(() => _monthView = v.first),
            ),
            gap8,
            if (!_monthView) ...[
              tile(l.earningsToday, e.today.trips, e.today.cash, const ValueKey('earnings_today')),
              tile(l.earningsWeek, e.totalTrips, e.totalCash, const ValueKey('earnings_week')),
            ] else ...[
              Row(children: [
                IconButton(
                  key: const ValueKey('month_prev'),
                  tooltip: ds.monthPrev,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftMonth(e.month, -1),
                ),
                Expanded(child: Text(monthName, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                  key: const ValueKey('month_next'),
                  tooltip: ds.monthNext,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: e.monthIsCurrent ? null : () => _shiftMonth(e.month, 1),
                ),
              ]),
              tile(monthName, e.monthTrips, e.monthCash, const ValueKey('earnings_month')),
            ],
            InfoBox(l.earningsNoCommission),
            gap16,
            if (days.isEmpty) Text(ds.earningsEmpty, textAlign: TextAlign.center),
            for (final d in days)
              ListTile(
                title: Text(formatDate(lang, d.date)),
                subtitle: Text(l.earningsTrips(d.trips)),
                trailing: Text(l.priceDh(d.cash), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
          ]);
        },
      ),
    );
  }
}

/// Daily goal progress, or a "Set a daily goal" button (D82). Also used on the home screen.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.earnings, this.onEdit, this.compact = false});

  final DriverEarnings earnings;
  final VoidCallback? onEdit;

  /// Home-screen version: one line + bar, no button when there is no goal.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final goal = earnings.goal;
    if (goal == null) {
      if (compact) return const SizedBox.shrink();
      return OutlinedButton.icon(
        key: const ValueKey('goal_set'),
        onPressed: onEdit,
        icon: const Icon(Icons.flag_outlined),
        label: Text(ds.goalSet),
      );
    }
    final reached = earnings.goalReached;
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Icon(reached ? Icons.emoji_events : Icons.flag, size: 18, color: reached ? BrandColors.accent : BrandColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(ds.goalProgress(earnings.today.cash, goal), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        if (onEdit != null && !compact)
          TextButton(key: const ValueKey('goal_edit'), onPressed: onEdit, child: Text(ds.goalEdit)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          key: const ValueKey('goal_progress'),
          value: earnings.goalProgress,
          minHeight: 6,
          color: reached ? BrandColors.accent : BrandColors.primary,
        ),
      ),
      const SizedBox(height: 4),
      Text(reached ? ds.goalReached : ds.goalLeft(earnings.goalLeft), style: const TextStyle(fontSize: 13)),
    ]);
    return Card(
      key: const ValueKey('goal_card'),
      child: InkWell(
        onTap: compact ? onEdit : null,
        child: Padding(padding: EdgeInsets.all(compact ? 10 : 16), child: body),
      ),
    );
  }
}
