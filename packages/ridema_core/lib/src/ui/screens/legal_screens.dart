import 'package:flutter/material.dart';

import '../../core_services.dart';
import '../../l10n/l10n.dart';
import '../../models/app_models.dart';
import '../widgets/common.dart';

/// Full text of one legal document.
class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.doc});
  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(doc.title, maxLines: 2)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.consentVersion(doc.version), style: TextStyle(color: Colors.grey.shade700)),
              gap16,
              SelectableText(doc.body, style: const TextStyle(fontSize: 16, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

String legalKindTitle(AppLocalizations l, String kind) => switch (kind) {
      LegalKind.terms => l.legalTerms,
      LegalKind.privacy => l.legalPrivacy,
      LegalKind.dataTransfer => l.legalDataTransfer,
      LegalKind.backgroundLocation => l.legalBackgroundLocation,
      _ => kind,
    };

/// Legal links + company identity (name, RC, ICE, address) from app config.
class LegalInfoScreen extends StatefulWidget {
  const LegalInfoScreen({super.key});

  @override
  State<LegalInfoScreen> createState() => _LegalInfoScreenState();
}

class _LegalInfoScreenState extends State<LegalInfoScreen> {
  Future<List<LegalDoc>>? _docs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _docs ??= CoreServices.of(context).api.legal(Localizations.localeOf(context).languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = CoreServices.of(context);
    final company = s.boot.appConfigOrDefault.company;
    final driver = s.config.isDriver;
    return Scaffold(
      appBar: AppBar(title: Text(l.legalTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            FutureBuilder<List<LegalDoc>>(
              future: _docs,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      ErrorBanner(l.consentsLoadFailed),
                      gap8,
                      SecondaryButton(
                        label: l.retry,
                        onPressed: () => setState(() => _docs = s.api.legal(Localizations.localeOf(context).languageCode)),
                      ),
                    ]),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                }
                final docs = snap.data!.where((d) => driver || d.kind != LegalKind.backgroundLocation);
                return Column(children: [
                  for (final d in docs)
                    ListTile(
                      leading: const Icon(Icons.article_outlined),
                      title: Text(legalKindTitle(l, d.kind)),
                      subtitle: Text(l.consentVersion(d.version)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalDocScreen(doc: d))),
                    ),
                ]);
              },
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CompanyInfoCard(company: company),
            ),
            gap16,
            Center(child: Text(l.profileAppVersion(s.config.version), style: TextStyle(color: Colors.grey.shade700))),
          ],
        ),
      ),
    );
  }
}

/// Company name, RC, ICE, address, support contacts.
class CompanyInfoCard extends StatelessWidget {
  const CompanyInfoCard({super.key, required this.company});
  final CompanyInfo company;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String v(String? x) => (x == null || x.isEmpty) ? '—' : x;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.companyTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            gap8,
            InfoRow(label: l.companyName, value: v(company.legalName ?? company.name)),
            InfoRow(label: l.companyRc, value: v(company.rc)),
            InfoRow(label: l.companyIce, value: v(company.ice)),
            InfoRow(label: l.companyAddress, value: v(company.address)),
            if (company.supportPhone != null) InfoRow(label: l.supportPhone, value: company.supportPhone!),
            if (company.supportEmail != null) InfoRow(label: l.supportEmail, value: company.supportEmail!),
          ],
        ),
      ),
    );
  }
}
