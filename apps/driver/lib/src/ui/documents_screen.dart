import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ridema_core/ridema_core.dart';

import '../controller/onboarding_validation.dart';
import '../controller/profile_controller.dart';
import '../l10n/driver_strings.dart';

/// Red banner: documents expiring within 30 days, or expired (blocked).
class DocumentsBanner extends StatelessWidget {
  const DocumentsBanner({super.key, required this.expiring, required this.expired, this.now, this.onTap});

  final List<DriverDocument> expiring;
  final List<DriverDocument> expired;
  final DateTime? now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (expiring.isEmpty && expired.isEmpty) return const SizedBox.shrink();
    final String text;
    if (expired.isNotEmpty) {
      text = l.docExpiredBlocked;
    } else {
      final d = expiring.first;
      final name = d.documentType == null ? d.type : documentTypeText(l, d.documentType!);
      text = l.docExpiringSoon(d.daysLeft(now) ?? 0, name);
    }
    return Material(
      key: const ValueKey('documents_banner'),
      color: BrandColors.danger,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(expired.isNotEmpty ? Icons.block : Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

/// List of documents with status and expiry; re-upload each.
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pc = context.watch<DriverProfileController>();
    final p = pc.profile;
    return Scaffold(
      appBar: AppBar(title: Text(l.documentsTitle)),
      body: RefreshIndicator(
        onRefresh: pc.load,
        child: ListView(children: [
          DocumentsBanner(expiring: pc.expiringWithin(30), expired: pc.expired()),
          if (p == null && pc.error != null)
            Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(errorText(l, pc.error!))),
          if (p != null) DocumentList(profile: p, onChanged: pc.load),
        ]),
      ),
    );
  }
}

/// One tile per required document type (used by Documents and the onboarding wizard).
class DocumentList extends StatelessWidget {
  const DocumentList({super.key, required this.profile, required this.onChanged});
  final DriverProfile profile;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final latest = profile.latestDocuments;
    return Column(children: [
      for (final t in OnboardingRules.requiredDocuments)
        Builder(builder: (context) {
          final d = latest[t.apiName];
          final left = d?.daysLeft();
          final status = d == null ? 'missing' : ((left != null && left < 0) ? 'expired' : d.status);
          final color = switch (status) {
            'approved' => BrandColors.success,
            'rejected' || 'expired' || 'missing' => BrandColors.danger,
            _ => BrandColors.accent,
          };
          final lines = <String>[
            documentStatusText(l, status),
            if (d?.expiresOn != null) l.docExpiresOn(formatDate(lang, d!.expiresOn)),
            if (d?.rejectReason != null && status == 'rejected') l.docRejectReason(d!.rejectReason!),
          ];
          final soon = left != null && left >= 0 && left <= 30;
          return ListTile(
            key: ValueKey('doc_${t.apiName}'),
            leading: Icon(Icons.description_outlined, color: color),
            title: Text(documentTypeText(l, t)),
            subtitle: Text(lines.join(' · '), style: TextStyle(color: soon ? BrandColors.danger : null)),
            trailing: TextButton(
              key: ValueKey('upload_${t.apiName}'),
              onPressed: () async {
                final ok = await showDocumentUploadSheet(context, t);
                if (ok) await onChanged();
              },
              child: Text(d == null ? l.docUpload : l.docReupload),
            ),
          );
        }),
    ]);
  }
}

/// Picks a photo (camera / gallery) or a file, asks the expiry date when needed, uploads.
Future<bool> showDocumentUploadSheet(BuildContext context, DocumentType type) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DocumentUploadSheet(type: type),
  );
  return ok ?? false;
}

class DocumentUploadSheet extends StatefulWidget {
  const DocumentUploadSheet({super.key, required this.type});
  final DocumentType type;

  static const maxBytes = 8 * 1024 * 1024;

  @override
  State<DocumentUploadSheet> createState() => _DocumentUploadSheetState();
}

class _DocumentUploadSheetState extends State<DocumentUploadSheet> {
  String? _path;
  DateTime? _expires;
  String? _error;
  bool _busy = false;

  Future<void> _pick(ImageSource? source) async {
    try {
      String? path;
      if (source == null) {
        final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp']);
        path = res.isEmpty ? null : res.first.path;
      } else {
        final x = await ImagePicker().pickImage(
          source: source,
          maxWidth: 2200,
          imageQuality: 85,
          preferredCameraDevice: widget.type == DocumentType.selfie ? CameraDevice.front : CameraDevice.rear,
        );
        path = x?.path;
      }
      if (path != null) setState(() => _path = path);
    } catch (e) {
      setState(() => _error = context.ds.loadFailed);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _expires ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(now.year + 15),
      helpText: context.l10n.docExpiryDate,
    );
    if (d != null) setState(() => _expires = d);
  }

  Future<void> _upload() async {
    final l = context.l10n;
    final ds = context.ds;
    final err = const OnboardingRules().document(widget.type, filePath: _path, expiresOn: _expires, today: DateTime.now());
    if (err != null) return setState(() => _error = ds.validation(l, err));
    try {
      if (File(_path!).lengthSync() > DocumentUploadSheet.maxBytes) return setState(() => _error = ds.fileTooLarge);
    } catch (_) {}
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CoreServices.of(context).api.uploadDocument(type: widget.type, filePath: _path!, expiresOn: _expires);
      if (!mounted) return;
      showInfoSnack(context, l.docUploaded);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ds.error(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final name = _path?.split(Platform.pathSeparator).last;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(documentTypeText(l, widget.type), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        gap8,
        InfoBox(l.docPhotoTips, icon: Icons.photo_camera_outlined),
        gap16,
        Row(children: [
          Expanded(
            child: SecondaryButton(key: const ValueKey('doc_camera'), label: l.docTakePhoto, icon: Icons.photo_camera, onPressed: _busy ? null : () => _pick(ImageSource.camera)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SecondaryButton(
              key: const ValueKey('doc_file'),
              label: l.docChooseFile,
              icon: Icons.folder_open,
              onPressed: _busy
                  ? null
                  : () async {
                      final source = await showModalBottomSheet<String>(
                        context: context,
                        builder: (c) => SafeArea(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            ListTile(leading: const Icon(Icons.photo_library), title: Text(l.docChooseFile), onTap: () => Navigator.pop(c, 'gallery')),
                            ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('PDF'), onTap: () => Navigator.pop(c, 'file')),
                          ]),
                        ),
                      );
                      if (source == 'gallery') await _pick(ImageSource.gallery);
                      if (source == 'file') await _pick(null);
                    },
            ),
          ),
        ]),
        if (name != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (widget.type.needsExpiry) ...[
          gap16,
          OutlinedButton.icon(
            key: const ValueKey('doc_expiry'),
            onPressed: _busy ? null : _pickDate,
            icon: const Icon(Icons.event),
            label: Text(_expires == null ? '${l.docExpiryDate}: ${context.ds.chooseDate}' : '${l.docExpiryDate}: ${formatDate(lang, _expires)}'),
          ),
        ],
        if (_error != null) ...[gap16, ErrorBanner(_error!)],
        gap16,
        PrimaryButton(key: const ValueKey('doc_send'), label: l.docUpload, busy: _busy, onPressed: _upload),
      ]),
    );
  }
}
