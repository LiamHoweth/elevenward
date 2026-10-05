import 'dart:io';

import 'package:crypto/crypto.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../online_copy.dart';
import '../util/uuid.dart';

final class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

final class _SupportScreenState extends State<SupportScreen> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _email = TextEditingController();
  String _category = 'bug';
  String _appVersion = 'unknown';
  String? _submissionId;
  String? _previousPayload;
  String? _statusKey;
  bool _includeDiagnostics = false;
  bool _sending = false;
  static const _draftKey = 'ui.supportDraft';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final draft = await widget.controller.store.getPreference(_draftKey);
    PackageInfo? info;
    try {
      info = await PackageInfo.fromPlatform();
    } on Object {
      /* Retry uses a safe version label. */
    }
    if (!mounted) return;
    setState(() {
      if (info != null) _appVersion = '${info.version}+${info.buildNumber}';
      if (draft is Map && _message.text.isEmpty) {
        _message.text = draft['message'] as String? ?? '';
        _email.text = draft['contactEmail'] as String? ?? '';
        _category = draft['category'] as String? ?? 'bug';
        _includeDiagnostics = draft.containsKey('diagnostics');
        _submissionId = draft['submissionId'] as String?;
        _previousPayload = draft['payload'] as String?;
      }
    });
  }

  Map<String, Object?>? get _savedBody {
    final payload = _previousPayload;
    if (payload == null) return null;
    try {
      return (jsonDecode(payload) as Map).cast<String, Object?>();
    } on Object {
      return null;
    }
  }

  bool _sameDraftFields(Map<String, Object?> body) =>
      body['category'] == _category &&
      body['message'] == _message.text.trim() &&
      (body['contactEmail'] ?? '') == _email.text.trim() &&
      body.containsKey('diagnostics') == _includeDiagnostics;

  Map<String, Object?> get _diagnostics {
    final saved = _savedBody;
    if (saved != null &&
        _sameDraftFields(saved) &&
        saved['diagnostics'] is Map) {
      return (saved['diagnostics'] as Map).cast<String, Object?>();
    }
    return {
      'locale': widget.controller.locale?.toLanguageTag() ?? 'en',
      'syncState': widget.controller.syncStatus.name,
      if (widget.controller.activeCareer case final career?) ...{
        'schemaVersion': career.schemaVersion,
        'rulesVersion': career.rulesVersion,
        'contentVersion': career.contentVersion,
      },
    };
  }

  Future<void> _send() async {
    if (_sending || !_form.currentState!.validate()) return;
    final careerId = widget.controller.activeCareer?.careerId;
    final saved = _savedBody;
    final body = saved != null && _sameDraftFields(saved)
        ? saved
        : <String, Object?>{
            'category': _category,
            'message': _message.text.trim(),
            if (_email.text.trim().isNotEmpty)
              'contactEmail': _email.text.trim(),
            'platform': Platform.isIOS
                ? 'ios'
                : Platform.isAndroid
                ? 'android'
                : Platform.isMacOS
                ? 'macos'
                : 'other',
            'appVersion': _appVersion,
            if (careerId != null)
              'supportCode': sha256
                  .convert(utf8.encode(careerId))
                  .toString()
                  .substring(0, 8)
                  .toUpperCase(),
            if (_includeDiagnostics) 'diagnostics': _diagnostics,
          };
    final payload = jsonEncode(body);
    if (_previousPayload != payload || _submissionId == null) {
      _submissionId = generateUuidV4();
    }
    _previousPayload = payload;
    body['submissionId'] = _submissionId;
    setState(() {
      _sending = true;
      _statusKey = null;
    });
    try {
      final draft = <String, Object?>{...body, 'payload': payload};
      await widget.controller.store.setPreference(_draftKey, draft);
      await widget.controller.sync.sendFeedback(body);
      await widget.controller.store.removePreferenceIfUnchanged(
        _draftKey,
        draft,
      );
      if (!mounted) return;
      setState(() {
        _statusKey = 'received';
        _message.clear();
        _email.clear();
        _submissionId = null;
        _previousPayload = null;
      });
    } on Object {
      if (mounted) setState(() => _statusKey = 'failed');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return Scaffold(
      appBar: AppBar(title: Text(onlineCopy(locale, 'support'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(onlineCopy(locale, 'supportBody')),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              key: const Key('feedback-category'),
              initialValue: _category,
              isExpanded: true,
              isDense: false,
              itemHeight: null,
              selectedItemBuilder: (context) => [
                for (final key in ['bug', 'feature', 'purchase', 'other'])
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(onlineCopy(locale, key), softWrap: true),
                  ),
              ],
              items: ['bug', 'feature', 'purchase', 'other']
                  .map(
                    (key) => DropdownMenuItem(
                      value: key,
                      child: Text(onlineCopy(locale, key), softWrap: true),
                    ),
                  )
                  .toList(),
              onChanged: _sending
                  ? null
                  : (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('feedback-message'),
              controller: _message,
              enabled: !_sending,
              onChanged: (_) => setState(() {}),
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: onlineCopy(locale, 'message'),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? onlineCopy(locale, 'invalidMessage')
                  : null,
            ),
            TextFormField(
              key: const Key('feedback-email'),
              controller: _email,
              enabled: !_sending,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.emailAddress,
              maxLength: 254,
              decoration: InputDecoration(
                labelText: onlineCopy(locale, 'email'),
              ),
              validator: (value) =>
                  value != null &&
                      value.trim().isNotEmpty &&
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value.trim())
                  ? onlineCopy(locale, 'invalidEmail')
                  : null,
            ),
            ExpansionTile(
              title: Text(onlineCopy(locale, 'diagnostics')),
              children: _diagnostics.entries
                  .map(
                    (e) => ListTile(
                      dense: true,
                      title: Text(e.key),
                      trailing: Text('${e.value}'),
                    ),
                  )
                  .toList(),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeDiagnostics,
              title: Text(onlineCopy(locale, 'reviewDiagnostics')),
              onChanged: _sending
                  ? null
                  : (value) => setState(() => _includeDiagnostics = value!),
            ),
            if (_statusKey != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(onlineCopy(locale, _statusKey!)),
                ),
              ),
            FilledButton(
              key: const Key('feedback-send'),
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(onlineCopy(locale, 'send')),
            ),
          ],
        ),
      ),
    );
  }
}
