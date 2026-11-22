import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api_client.dart';

class RhmDevicePairingDialog extends StatefulWidget {
  const RhmDevicePairingDialog({
    super.key,
    required this.serverUrl,
    required this.onPaired,
  });

  final String serverUrl;
  final Future<void> Function({
    required String accessToken,
    required String refreshToken,
    required String deviceId,
    required String privateKeySeed,
    required String publicKey,
  }) onPaired;

  @override
  State<RhmDevicePairingDialog> createState() => _RhmDevicePairingDialogState();
}

class _RhmDevicePairingDialogState extends State<RhmDevicePairingDialog> {
  static const _pendingServerKey = 'rhm_pairing_pending_server';
  static const _pendingIdKey = 'rhm_pairing_pending_id';
  static const _pendingCodeKey = 'rhm_pairing_pending_code';
  static const _pendingSecretKey = 'rhm_pairing_pending_secret';
  static const _pendingChallengeKey = 'rhm_pairing_pending_challenge';
  static const _pendingExpiryKey = 'rhm_pairing_pending_expiry';
  static const _pendingPrivateKey = 'rhm_pairing_pending_private_seed';
  static const _pendingPublicKey = 'rhm_pairing_pending_public_key';
  static const _devicePrivateKey = 'rhm_device_private_key_seed';
  static const _devicePublicKey = 'rhm_device_public_key';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: true,
      migrateWithBackup: true,
    ),
  );

  final _algorithm = Ed25519();
  RhmApiClient? _api;
  Map<String, dynamic>? _request;
  KeyPair? _keyPair;
  String? _privateKeySeed;
  String? _publicKey;
  String _status = 'جارٍ إعداد ربط آمن بهذا الهاتف…';
  String? _error;
  bool _busy = true;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_beginPairing());
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  String _encodeUrlSafe(List<int> bytes) =>
      base64UrlEncode(bytes).replaceAll('=', '');

  Future<void> _beginPairing() async {
    try {
      _api = RhmApiClient(serverUrl: widget.serverUrl);
      final savedServer = await _storage.read(key: _pendingServerKey);
      final savedId = await _storage.read(key: _pendingIdKey);
      final savedCode = await _storage.read(key: _pendingCodeKey);
      final savedSecret = await _storage.read(key: _pendingSecretKey);
      final savedChallenge = await _storage.read(key: _pendingChallengeKey);
      final savedExpiry = await _storage.read(key: _pendingExpiryKey);
      final savedPrivate = await _storage.read(key: _pendingPrivateKey);
      final savedPublic = await _storage.read(key: _pendingPublicKey);

      if (savedServer == widget.serverUrl &&
          savedId != null &&
          savedCode != null &&
          savedSecret != null &&
          savedChallenge != null &&
          savedExpiry != null &&
          savedPrivate != null &&
          savedPublic != null) {
        final expiry = DateTime.tryParse(savedExpiry);
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          final seed = base64Url.decode(base64Url.normalize(savedPrivate));
          _keyPair = await _algorithm.newKeyPairFromSeed(seed);
          _privateKeySeed = savedPrivate;
          _publicKey = savedPublic;
          _request = {
            'request_id': savedId,
            'pairing_code': savedCode,
            'pairing_secret': savedSecret,
            'challenge': savedChallenge,
            'expires_at': savedExpiry,
          };
          if (mounted) {
            setState(() {
              _busy = false;
              _status = 'طلب الربط السابق ما زال صالحًا. وافق عليه من Termux ثم تحقق.';
            });
          }
          return;
        }
      }

      await _clearPending();
      final existingPrivateSeed = await _storage.read(key: _devicePrivateKey);
      final existingPublicKey = await _storage.read(key: _devicePublicKey);
      late final KeyPair keyPair;
      late final String privateSeed;
      late final String publicKey;
      if (existingPrivateSeed != null && existingPublicKey != null) {
        final seed = base64Url.decode(base64Url.normalize(existingPrivateSeed));
        keyPair = await _algorithm.newKeyPairFromSeed(seed);
        privateSeed = existingPrivateSeed;
        publicKey = existingPublicKey;
      } else {
        keyPair = await _algorithm.newKeyPair();
        final keyData = await keyPair.extract();
        final publicKeyData = await keyPair.extractPublicKey();
        privateSeed = _encodeUrlSafe(keyData.bytes);
        publicKey = _encodeUrlSafe(publicKeyData.bytes);
      }
      final request = await _api!.createDevicePairingRequest(
        name: 'RHM Android phone',
        publicKey: publicKey,
      );
      await _storage.write(key: _pendingServerKey, value: widget.serverUrl);
      await _storage.write(key: _pendingIdKey, value: request['request_id'] as String);
      await _storage.write(key: _pendingCodeKey, value: request['pairing_code'] as String);
      await _storage.write(key: _pendingSecretKey, value: request['pairing_secret'] as String);
      await _storage.write(key: _pendingChallengeKey, value: request['challenge'] as String);
      await _storage.write(key: _pendingExpiryKey, value: request['expires_at'] as String);
      await _storage.write(key: _pendingPrivateKey, value: privateSeed);
      await _storage.write(key: _pendingPublicKey, value: publicKey);
      if (!mounted) return;
      setState(() {
        _keyPair = keyPair;
        _privateKeySeed = privateSeed;
        _publicKey = publicKey;
        _request = request;
        _busy = false;
        _status = 'تم إنشاء طلب ربط لمرة واحدة. أكمل موافقة المالك من Termux.';
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is RhmApiException
            ? error.message
            : 'تعذر إعداد الربط الآمن. تحقق من تشغيل خادم RHM.';
      });
    }
  }

  Future<void> _checkApproval() async {
    final request = _request;
    final keyPair = _keyPair;
    final api = _api;
    if (request == null || keyPair == null || api == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'جارٍ التحقق من موافقة المالك…';
    });
    try {
      final requestId = request['request_id'] as String;
      final challenge = request['challenge'] as String;
      final proof = 'RHM-PAIR-v1\n$requestId\n$challenge';
      final signature = await _algorithm.sign(
        utf8.encode(proof),
        keyPair: keyPair,
      );
      final result = await api.completeDevicePairingRequest(
        requestId: requestId,
        pairingSecret: request['pairing_secret'] as String,
        signature: _encodeUrlSafe(signature.bytes),
      );
      if (result == null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _status = 'لم تتم الموافقة بعد. بعد تنفيذ أمر الموافقة في Termux اضغط تحقق مرة أخرى.';
          });
        }
        return;
      }

      await widget.onPaired(
        accessToken: result['access_token'] as String,
        refreshToken: result['refresh_token'] as String,
        deviceId: result['device_id'] as String,
        privateKeySeed: _privateKeySeed!,
        publicKey: _publicKey!,
      );
      await _clearPending();
      if (!mounted) return;
      setState(() {
        _completed = true;
        _busy = false;
        _status = 'اكتمل ربط هذا الهاتف بنجاح.';
      });
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is RhmApiException
            ? error.message
            : 'تعذر إكمال الربط. لم تُحذف بيانات الاتصال السابقة.';
      });
    }
  }

  Future<void> _copyCode() async {
    final code = _request?['pairing_code'];
    if (code is! String) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ رمز الربط لمرة واحدة.')),
      );
    }
  }

  Future<void> _clearPending() async {
    for (final key in [
      _pendingServerKey,
      _pendingIdKey,
      _pendingCodeKey,
      _pendingSecretKey,
      _pendingChallengeKey,
      _pendingExpiryKey,
      _pendingPrivateKey,
      _pendingPublicKey,
    ]) {
      await _storage.delete(key: key);
    }
  }

  Future<void> _restartPairingRequest() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = 'جارٍ إنشاء طلب ربط جديد…';
    });
    await _clearPending();
    if (!mounted) return;
    await _beginPairing();
  }

  Future<void> _resetRevokedIdentity() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = 'جارٍ إنشاء هوية جديدة لهذا الهاتف…';
    });
    for (final key in [
      _devicePrivateKey,
      _devicePublicKey,
      'rhm_device_id',
      'rhm_device_access_token',
      'rhm_device_refresh_token',
    ]) {
      await _storage.delete(key: key);
    }
    await _clearPending();
    if (!mounted) return;
    await _beginPairing();
  }

  @override
  Widget build(BuildContext context) {
    final code = _request?['pairing_code'] as String?;
    return AlertDialog(
      title: const Text('ربط الهاتف بخادم RHM'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy && _request == null)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            if (code != null) ...[
              const Text(
                'اعرض رمز الربط أو انسخه، ثم افتح Termux ونفّذ الأمر التالي:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const SelectableText(
                'rhm device approve',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              QrImageView(
                data: code,
                size: 164,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 8),
              SelectableText(
                code,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: _copyCode,
                icon: const Icon(Icons.copy),
                label: const Text('نسخ رمز الربط'),
              ),
              const Text(
                'أدخل الرمز في Termux عند طلبه. الرمز صالح لمدة 10 دقائق ويُستخدم مرة واحدة.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              _status,
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_error?.toLowerCase().contains('revoked') == true ||
            _error?.toLowerCase().contains('no longer active') == true)
          TextButton(
            onPressed: _busy ? null : _resetRevokedIdentity,
            child: const Text('إنشاء هوية جديدة'),
          ),
        if (_request != null && _error != null)
          TextButton(
            onPressed: _busy ? null : _restartPairingRequest,
            child: const Text('إنشاء طلب ربط جديد'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('إغلاق'),
        ),
        FilledButton(
          onPressed: _busy || code == null || _completed ? null : _checkApproval,
          child: Text(_busy ? 'جارٍ التحقق…' : 'تحقق من الموافقة'),
        ),
      ],
    );
  }
}
