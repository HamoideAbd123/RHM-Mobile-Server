part of 'chat_screen.dart';

extension _ChatScreenConnection on _ChatScreenState {
  Future<void> _bootstrap() async {
    await _restoreAppPreferences();
    await _restoreComposerDraft();
    if (!mounted) return;
    await _restoreConnection();
  }

  Future<void> _restoreConnection() async {
    String? savedUrl;
    String? token;
    String? deviceAccessToken;
    String? deviceRefreshToken;
    try {
      savedUrl = await _ChatScreenState._storage.read(key: _ChatScreenState._serverKey);
      token = await _ChatScreenState._storage.read(key: _ChatScreenState._tokenKey);
      deviceAccessToken = await _ChatScreenState._storage.read(key: _ChatScreenState._deviceAccessTokenKey);
      deviceRefreshToken = await _ChatScreenState._storage.read(key: _ChatScreenState._deviceRefreshTokenKey);
    } catch (_) {
      // Never erase credentials as a side effect of a read/decryption error.
      // Keep the user on the chat screen and surface a recoverable warning.
      if (!mounted) return;
      _setState(() {
        _status = 'تعذر قراءة بيانات الاتصال من التخزين الآمن. لم تُحذف بياناتك؛ أعد تشغيل التطبيق والهاتف ثم أعد المحاولة.';
        _error = 'تعذر الوصول إلى رمز RHM المحفوظ.';
      });
      return;
    }

    if (!mounted) return;
    final url = savedUrl?.trim().isNotEmpty == true
        ? savedUrl!.trim()
        : RhmApiClient.defaultServerUrl;
    _serverUrl.text = url;
    final effectiveToken = deviceAccessToken ?? token;
    if ((effectiveToken == null || effectiveToken.trim().isEmpty) &&
        (deviceRefreshToken == null || deviceRefreshToken.isEmpty)) {
      _setState(() {
        _status = 'عنوان الخادم محفوظ. يمكنك ربط هذا الهاتف بموافقة المالك دون إدخال الرمز الرئيسي.';
      });
      return;
    }

    final api = RhmApiClient(
      serverUrl: url,
      token: effectiveToken,
      refreshToken: deviceRefreshToken,
      onCredentialsRotated: _persistDeviceCredentials,
    );
    if (!mounted) {
      api.close();
      return;
    }
    _setState(() {
      _api = api;
      _activeServerUrl = url;
      _serverUrl.text = url;
      _status = 'تم استعادة إعداد الاتصال المحفوظ.';
      _error = null;
    });

    try {
      await api.checkConnection();
      if (deviceRefreshToken != null && api.accessToken != null) {
        await _clearAndroidHealthToken();
      } else if (token != null && token.isNotEmpty) {
        await _syncAndroidHealthToken(token);
      }
      if (!mounted) return;
      _setState(() => _connectionReady = true);
      await RhmServerUpdateNotifications.instance.prime(api);
      await _loadProviders();
      await _loadProjects();
      await _restoreConversation();
      if (mounted) {
        _setState(() {
          _connectionReady = true;
          _status = 'اتصال محلي بخادم RHM جاهز.';
          _error = null;
        });
      }
    } on RhmApiException catch (error) {
      if (mounted) {
        _setState(() {
          _connectionReady = false;
          _status = 'تم استعادة بيانات الاتصال، لكن الخادم لم يقبل الاتصال حاليًا.';
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        _setState(() {
          _connectionReady = false;
          _status = 'الخادم غير متاح حاليًا؛ بيانات الاتصال ما زالت محفوظة.';
          _error = null;
        });
      }
    }
  }

  Future<void> _verifyConnection() async {
    final api = _api;
    if (api == null || _checkingConnection) {
      if (api == null && mounted) {
        _setState(() {
          _connectionReady = false;
          _status = 'أدخل إعدادات الاتصال أولًا.';
        });
      }
      return;
    }

    _setState(() {
      _checkingConnection = true;
      _error = null;
      _status = 'جارٍ اختبار الاتصال بخادم RHM…';
    });
    try {
      await api.checkConnection();
      final deviceAccess = await _ChatScreenState._storage.read(
        key: _ChatScreenState._deviceAccessTokenKey,
      );
      final deviceRefresh = await _ChatScreenState._storage.read(
        key: _ChatScreenState._deviceRefreshTokenKey,
      );
      final savedToken = await _ChatScreenState._storage.read(key: _ChatScreenState._tokenKey);
      if (deviceAccess != null && deviceRefresh != null) {
        await _clearAndroidHealthToken();
      } else if (savedToken != null && savedToken.isNotEmpty) {
        await _syncAndroidHealthToken(savedToken);
      }
      if (!mounted) return;
      _setState(() {
        _connectionReady = true;
        _status = 'الاتصال بخادم RHM يعمل بصورة سليمة.';
        _error = null;
      });
      await _loadProviders();
      await _loadProjects();
    } on RhmApiException catch (error) {
      if (!mounted) return;
      _setState(() {
        _connectionReady = false;
        _status = 'فشل اختبار الاتصال. إعداداتك المحفوظة لم تُحذف.';
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      _setState(() {
        _connectionReady = false;
        _status = 'تعذر اختبار الاتصال. إعداداتك المحفوظة لم تُحذف.';
        _error = 'تحقق من تشغيل FastAPI على 127.0.0.1:8000.';
      });
    } finally {
      if (mounted) _setState(() => _checkingConnection = false);
    }
  }

  Future<void> _showConnectionSettings() async {
    _token.clear();
    _error = null;
    final connected = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('الاتصال بخادم RHM'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _serverUrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'عنوان خادم RHM',
                    hintText: 'http://127.0.0.1:8000',
                  ),
                ),
                TextField(
                  controller: _token,
                  obscureText: true,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'رمز الوصول (اختياري عند وجود رمز محفوظ)',
                    helperText: 'اتركه فارغًا للاحتفاظ بالرمز الحالي.',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'للاتصال على هذا الهاتف استخدم http://127.0.0.1:8000. لن نطلب الرمز مجددًا عند فتح التطبيق ما دام محفوظًا وصالحًا. أدخل رمزًا جديدًا فقط عند تغييره أو عند فشل المصادقة.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () async {
                final requestedUrl = _serverUrl.text.trim();
                try {
                  final paired = await showDialog<bool>(
                    context: context,
                    builder: (_) => RhmDevicePairingDialog(
                      serverUrl: requestedUrl,
                      onPaired: _savePairedDeviceCredentials,
                    ),
                  );
                  if (paired == true && context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (_) {
                  if (context.mounted) {
                    setDialogState(() => _error = 'تعذر بدء ربط الجهاز. تحقق من عنوان الخادم.');
                  }
                }
              },
              child: const Text('ربط آمن دون الرمز الرئيسي'),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: _busy ? null : () => _connect(context, setDialogState),
              child: Text(_busy ? 'جارٍ التحقق…' : 'تحقق واتصل'),
            ),
          ],
        ),
      ),
    );
    if (mounted) _token.clear();
    if (connected == false && mounted && _api == null) {
      _setState(() => _status = 'لم يتم الاتصال. يمكنك الكتابة بعد إعداد الخادم.');
    }
  }

  Future<void> _connect(
    BuildContext dialogContext,
    void Function(void Function()) setDialogState,
  ) async {
    var connected = false;
    setDialogState(() {
      _busy = true;
      _error = null;
    });
    _setState(() {
      _busy = true;
      _error = null;
    });

    RhmApiClient? candidate;
    try {
      final requestedUrl = _serverUrl.text.trim();
      final enteredToken = _token.text.trim();
      final reuseSavedToken = enteredToken.isEmpty &&
          _api != null &&
          _activeServerUrl == requestedUrl;

      if (reuseSavedToken) {
        // Verify the existing authenticated client; never ask for the
        // already-saved token merely because settings were opened.
        await _api!.checkConnection();
      } else {
        if (enteredToken.isEmpty) {
          throw const RhmApiException(
            'لا يوجد رمز محفوظ لهذا العنوان. أدخل رمز الوصول مرة واحدة لإكمال الاتصال.',
          );
        }
        candidate = RhmApiClient(
          serverUrl: requestedUrl,
          token: enteredToken,
        );
        await candidate.checkConnection();
        if (!mounted || !dialogContext.mounted) return;

        // Store only after the server has accepted the token.
        await _ChatScreenState._storage.write(key: _ChatScreenState._serverKey, value: requestedUrl);
        await _ChatScreenState._storage.write(key: _ChatScreenState._tokenKey, value: enteredToken);
        for (final key in [
          _ChatScreenState._deviceAccessTokenKey,
          _ChatScreenState._deviceRefreshTokenKey,
          _ChatScreenState._deviceIdKey,
          _ChatScreenState._devicePrivateKeyKey,
          _ChatScreenState._devicePublicKeyKey,
        ]) {
          await _ChatScreenState._storage.delete(key: key);
        }
        await _syncAndroidHealthToken(enteredToken);
        final previous = _api;
        _api = candidate;
        _activeServerUrl = requestedUrl;
        candidate = null;
        previous?.close();
      }

      if (!mounted || !dialogContext.mounted) return;
      _token.clear();
      _setState(() {
        _connectionReady = true;
        _status = 'اتصال محلي بخادم RHM جاهز.';
        _error = null;
      });
      connected = true;
      await _loadProviders();
      await _loadProjects();
      await _restoreConversation();
    } on RhmApiException catch (error) {
      if (dialogContext.mounted) setDialogState(() => _error = error.message);
      if (mounted) _setState(() => _error = error.message);
    } catch (_) {
      if (dialogContext.mounted) {
        setDialogState(() => _error = 'تعذر الاتصال أو حفظ الإعدادات بأمان.');
      }
      if (mounted) _setState(() => _error = 'تعذر الاتصال أو حفظ الإعدادات بأمان.');
    } finally {
      candidate?.close();
      if (mounted) {
        if (dialogContext.mounted) setDialogState(() => _busy = false);
        _setState(() => _busy = false);
      }
    }
    if (connected && dialogContext.mounted) {
      Navigator.pop(dialogContext, true);
    }
  }


  Future<void> _persistDeviceCredentials(
    String accessToken,
    String refreshToken,
  ) async {
    await _ChatScreenState._storage.write(
      key: _ChatScreenState._deviceAccessTokenKey,
      value: accessToken,
    );
    await _ChatScreenState._storage.write(
      key: _ChatScreenState._deviceRefreshTokenKey,
      value: refreshToken,
    );
    // Native runtime monitoring uses the public loopback /health liveness
    // endpoint, so it never receives or shares this rotating refresh token.
  }

  Future<void> _savePairedDeviceCredentials({
    required String accessToken,
    required String refreshToken,
    required String deviceId,
    required String privateKeySeed,
    required String publicKey,
  }) async {
    final url = _serverUrl.text.trim();
    final candidate = RhmApiClient(
      serverUrl: url,
      token: accessToken,
      refreshToken: refreshToken,
      onCredentialsRotated: _persistDeviceCredentials,
    );
    try {
      await candidate.checkConnection();
      await _ChatScreenState._storage.write(
        key: _ChatScreenState._serverKey,
        value: url,
      );
      await _ChatScreenState._storage.write(
        key: _ChatScreenState._deviceAccessTokenKey,
        value: candidate.accessToken ?? accessToken,
      );
      await _ChatScreenState._storage.write(
        key: _ChatScreenState._deviceRefreshTokenKey,
        value: refreshToken,
      );
      await _ChatScreenState._storage.write(
        key: _ChatScreenState._deviceIdKey,
        value: deviceId,
      );
      await _ChatScreenState._storage.write(
        key: _ChatScreenState._devicePrivateKeyKey,
        value: privateKeySeed,
      );
      await _ChatScreenState._storage.write(
        key: _ChatScreenState._devicePublicKeyKey,
        value: publicKey,
      );
      await _ChatScreenState._storage.delete(key: _ChatScreenState._tokenKey);
      final previous = _api;
      _api = candidate;
      _activeServerUrl = url;
      if (mounted) {
        _setState(() {
          _connectionReady = true;
          _status = 'تم ربط هذا الهاتف باعتماد مستقل وآمن.';
          _error = null;
        });
      }
      previous?.close();
      await _clearAndroidHealthToken();
      await _loadProviders();
      await _loadProjects();
      await _restoreConversation();
    } catch (_) {
      candidate.close();
      rethrow;
    }
  }

  Future<void> _loadProviders() async {
    if (_api == null) return;
    _setState(() => _loadingProviders = true);
    try {
      final values = await _api!.getProviders();
      if (!mounted) return;
      _setState(() {
        _providers = values;
        final matches = values.where((p) => p.provider == _preferredProvider && p.configured && p.models.isNotEmpty);
        if (matches.isEmpty) { _preferredProvider = null; _preferredModel = null; }
        else if (_preferredModel != null && !matches.first.models.contains(_preferredModel)) {
          _preferredModel = null;
        }
      });
    } on RhmApiException catch (e) { if (mounted) _setState(() => _error = e.message); }
    finally { if (mounted) _setState(() => _loadingProviders = false); }
  }

  Future<void> _loadProjects() async {
    final api = _api;
    if (api == null) return;
    try {
      final projects = await api.listProjects();
      if (!mounted) return;
      _setState(() {
        _projects = projects;
        if (_composerDraftProjectName != null &&
            _projects.any((project) => project.name == _composerDraftProjectName) &&
            _pendingRequestId == null) {
          _selectedProjectName = _composerDraftProjectName;
        }
        if (_selectedProjectName != null &&
            !_projects.any((project) => project.name == _selectedProjectName) &&
            !_projectScopeInitialized) {
          _selectedProjectName = null;
        }
      });
    } on RhmApiException catch (error) {
      if (mounted) _setState(() => _error = error.message);
    }
  }
}
