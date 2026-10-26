import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../../controller/onboarding_validation.dart';
import '../../controller/profile_controller.dart';
import '../../l10n/driver_strings.dart';
import '../documents_screen.dart';

/// Onboarding wizard (SPEC §3.3.1): driver type → about you → car → documents → submit.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.today});

  /// Clock override (tests).
  final DateTime? today;

  static const steps = 5;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _rules = OnboardingRules();

  int _step = 0;
  bool _busy = false;
  String? _error;
  List<City> _cities = const [];
  bool _citiesLoaded = false;

  String? _cityId;
  String? _type;
  final _cin = TextEditingController();
  DateTime? _licence;
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _colour = TextEditingController();
  final _plate = TextEditingController();
  int? _doors = 4;
  bool? _ac;
  final _formPersonal = GlobalKey<FormState>();
  final _formVehicle = GlobalKey<FormState>();
  bool _prefilled = false;

  DateTime get _today => widget.today ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCities());
  }

  @override
  void dispose() {
    for (final c in [_cin, _make, _model, _year, _colour, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(DriverProfile p) {
    if (_prefilled) return;
    _prefilled = true;
    _cityId = p.city?.id;
    _type = p.driverType;
    _cin.text = p.cinLast4 ?? '';
    _licence = p.licenceIssuedOn;
    final v = p.vehicle;
    if (v != null) {
      _make.text = v.make;
      _model.text = v.model;
      _year.text = v.year == 0 ? '' : '${v.year}';
      _colour.text = v.colour;
      _plate.text = v.plate;
      _doors = v.doors;
      _ac = v.hasAc;
    }
  }

  Future<void> _loadCities() async {
    try {
      final list = await CoreServices.of(context).api.cities();
      if (!mounted) return;
      setState(() {
        _cities = list;
        _citiesLoaded = true;
        if (_cityId == null && list.length == 1) _cityId = list.first.id;
      });
    } catch (e) {
      if (mounted) setState(() => _error = context.ds.error(context.l10n, e));
    }
  }

  City? get _city {
    for (final c in _cities) {
      if (c.id == _cityId) return c;
    }
    final p = context.read<DriverProfileController>().profile?.city;
    return p != null && p.id == _cityId ? p : null;
  }

  String? _v(String? key) => key == null ? null : context.ds.validation(context.l10n, key, today: _today);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = context.ds.error(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    final api = CoreServices.of(context).api;
    final pc = context.read<DriverProfileController>();
    switch (_step) {
      case 0:
        final err = _cityId == null ? OnboardingError.required : _rules.driverType(_type, _city?.enabledDriverTypes ?? const []);
        if (err != null) return setState(() => _error = _v(err));
        setState(() {
          _error = null;
          _step = 1;
        });
      case 1:
        final licenceErr = _rules.licenceIssuedOn(_licence, _today);
        if (!(_formPersonal.currentState?.validate() ?? false) || licenceErr != null) {
          return setState(() => _error = _v(licenceErr));
        }
        await _run(() async {
          pc.set(await api.updateDriverProfile(
            cityId: _cityId!,
            driverType: _type!,
            cinLast4: _cin.text.trim().toUpperCase(),
            licenceIssuedOn: _licence!,
          ));
          setState(() => _step = 2);
        });
      case 2:
        final acErr = _rules.vehicleAc(_ac);
        final doorsErr = _rules.vehicleDoors(_doors);
        if (!(_formVehicle.currentState?.validate() ?? false) || acErr != null || doorsErr != null) {
          return setState(() => _error = _v(doorsErr ?? acErr));
        }
        await _run(() async {
          pc.set(await api.updateVehicle(
            make: _make.text.trim(),
            model: _model.text.trim(),
            year: int.parse(_year.text.trim()),
            colour: _colour.text.trim(),
            plate: _plate.text.trim().toUpperCase(),
            doors: _doors!,
            hasAc: _ac!,
          ));
          setState(() => _step = 3);
        });
      case 3:
        setState(() {
          _error = null;
          _step = 4;
        });
      case 4:
        await _run(() async => pc.set(await api.submitForReview()));
    }
  }

  Future<void> _pickLicence() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _licence ?? _rules.latestLicenceDate(_today),
      firstDate: DateTime(1960),
      lastDate: _today,
      helpText: context.l10n.licenceIssuedLabel,
    );
    if (d != null) setState(() => _licence = d);
  }

  Widget _stepType(AppLocalizations l) {
    final city = _city;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.driverTypeTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      gap8,
      Text(context.ds.draftIntro),
      gap16,
      if (!_citiesLoaded && _cities.isEmpty) const Center(child: CircularProgressIndicator()),
      if (_cities.length > 1)
        DropdownButtonFormField<String>(
          key: const ValueKey('city_field'),
          initialValue: _cityId,
          decoration: InputDecoration(labelText: context.ds.cityLabel),
          items: [for (final c in _cities) DropdownMenuItem(value: c.id, child: Text(c.name(Localizations.localeOf(context).languageCode)))],
          onChanged: (v) => setState(() {
            _cityId = v;
            _type = null;
          }),
        ),
      if (city != null) ...[
        gap8,
        RadioGroup<String>(
          groupValue: _type,
          onChanged: (v) => setState(() => _type = v),
          child: Column(children: [
            for (final t in city.enabledDriverTypes)
              RadioListTile<String>(key: ValueKey('type_$t'), value: t, title: Text(driverTypeText(l, t), style: const TextStyle(fontSize: 17))),
          ]),
        ),
      ],
    ]);
  }

  Widget _stepPersonal(AppLocalizations l) {
    final lang = Localizations.localeOf(context).languageCode;
    return Form(
      key: _formPersonal,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.personalInfoTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        gap16,
        TextFormField(
          key: const ValueKey('cin_field'),
          controller: _cin,
          maxLength: 4,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
          decoration: InputDecoration(labelText: l.cinLast4Label, helperText: l.cinLast4Hint, helperMaxLines: 2),
          validator: (v) => _v(_rules.cinLast4(v)),
        ),
        gap16,
        OutlinedButton.icon(
          key: const ValueKey('licence_field'),
          onPressed: _pickLicence,
          icon: const Icon(Icons.event),
          label: Text('${l.licenceIssuedLabel}: ${_licence == null ? context.ds.chooseDate : formatDate(lang, _licence)}'),
        ),
      ]),
    );
  }

  Widget _stepVehicle(AppLocalizations l) {
    final ds = context.ds;
    InputDecoration dec(String label, {String? helper}) => InputDecoration(labelText: label, helperText: helper);
    return Form(
      key: _formVehicle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.vehicleTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        gap8,
        TextFormField(key: const ValueKey('make_field'), controller: _make, decoration: dec(l.vehicleMake), validator: (v) => _v(_rules.text(v))),
        TextFormField(key: const ValueKey('model_field'), controller: _model, decoration: dec(l.vehicleModel), validator: (v) => _v(_rules.text(v))),
        TextFormField(
          key: const ValueKey('year_field'),
          controller: _year,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: dec(l.vehicleYear, helper: l.errorCarTooOld(_rules.minCarYear(_today))),
          validator: (v) => _v(_rules.vehicleYear(int.tryParse(v ?? ''), _today)),
        ),
        TextFormField(key: const ValueKey('colour_field'), controller: _colour, decoration: dec(l.vehicleColour), validator: (v) => _v(_rules.text(v))),
        TextFormField(
          key: const ValueKey('plate_field'),
          controller: _plate,
          textCapitalization: TextCapitalization.characters,
          decoration: dec(l.vehiclePlate),
          validator: (v) => _v(_rules.plate(v)),
        ),
        gap16,
        DropdownButtonFormField<int>(
          key: const ValueKey('doors_field'),
          initialValue: _doors,
          decoration: dec(l.vehicleDoors),
          items: [for (final n in [2, 3, 4, 5]) DropdownMenuItem(value: n, child: Text('$n'))],
          onChanged: (v) => setState(() => _doors = v),
          validator: (v) => _v(_rules.vehicleDoors(v)),
        ),
        gap16,
        Text(l.vehicleAc, style: const TextStyle(fontSize: 16)),
        gap8,
        SegmentedButton<bool>(
          key: const ValueKey('ac_field'),
          emptySelectionAllowed: true,
          segments: [
            ButtonSegment(value: true, label: Text(ds.acYes)),
            ButtonSegment(value: false, label: Text(ds.acNo)),
          ],
          selected: {?_ac},
          onSelectionChanged: (s) => setState(() => _ac = s.isEmpty ? null : s.first),
        ),
      ]),
    );
  }

  Widget _stepDocuments(AppLocalizations l, DriverProfile? p) {
    final pc = context.read<DriverProfileController>();
    final missing = p == null
        ? OnboardingRules.requiredDocuments.length
        : OnboardingRules.requiredDocuments.where((t) => !p.latestDocuments.containsKey(t.apiName)).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.documentsStepTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      gap8,
      InfoBox(missing == 0 ? context.ds.docsAllSent : context.ds.docsMissing(missing),
          icon: missing == 0 ? Icons.check_circle_outline : Icons.upload_file),
      if (p != null) DocumentList(profile: p, onChanged: pc.load),
    ]);
  }

  Widget _stepReview(AppLocalizations l, DriverProfile? p) {
    final v = p?.vehicle;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.submitForReview, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      gap16,
      if (p?.driverType != null) InfoRow(label: l.driverTypeTitle, value: driverTypeText(l, p!.driverType!)),
      InfoRow(label: l.cinLast4Label, value: p?.cinLast4 ?? '—'),
      InfoRow(label: l.vehicleTitle, value: v == null ? context.ds.noVehicleYet : '${v.make} ${v.model} ${v.year} · ${v.plate}'),
      gap16,
      InfoBox(l.underReviewBody),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pc = context.watch<DriverProfileController>();
    final p = pc.profile;
    if (p != null) _prefill(p);
    final body = switch (_step) {
      0 => _stepType(l),
      1 => _stepPersonal(l),
      2 => _stepVehicle(l),
      3 => _stepDocuments(l, p),
      _ => _stepReview(l, p),
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.onboardingTitle),
          leading: _step > 0 ? BackButton(onPressed: () => setState(() => _step--)) : null,
          actions: [
            IconButton(
              tooltip: l.profileTitle,
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen(showTrips: false))),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            LinearProgressIndicator(value: (_step + 1) / OnboardingScreen.steps),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.onboardingStep(_step + 1, OnboardingScreen.steps), key: const ValueKey('onboarding_step')),
            ),
            if (p?.status == DriverStatus.rejected && p?.statusReason != null)
              Padding(padding: const EdgeInsets.all(12), child: ErrorBanner(l.rejectedBody(p!.statusReason!))),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: body)),
            if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: ErrorBanner(_error!)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryButton(
                key: const ValueKey('onboarding_next'),
                label: _step == OnboardingScreen.steps - 1 ? l.submitForReview : l.next,
                busy: _busy,
                onPressed: _next,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
