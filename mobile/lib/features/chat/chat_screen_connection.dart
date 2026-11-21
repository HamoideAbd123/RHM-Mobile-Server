part of 'chat_screen.dart';

extension _ChatScreenConnection on _ChatScreenState {
  Future<void> this._bootstrap() async {
    await this._restoreAppPreferences();
    await this._restoreComposerDraft();
    if (!mounted) return;
    await this._restoreConnection();
  }

  Future<void> this._restoreConnection() async {
    String? savedUrl;
    String? token;
    try {
      savedUrl = await _ChatScreenState._storage.read(key: _ChatScreenState._serverKey);
      token = await _ChatScreenState._storage.read(key: _ChatScreenState._tokenKey);
    } catch (_) {
      // Never erase credentials as a side effect of a read/decryption error.
      // Keep the user on the chat screen and surface a recoverable warning.
      if (!mounted) return;
      this._setState(() {
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
    if (token == null || token.trim().isEmpty) {
      this._setState(() {
        _status = 'عنوان الخادم محفوظ؛ أدخل رمز الوصول مرة واحدة لإكمال الاتصال.';
      });
      return;
    }

    final api = RhmApiClient(serverUrl: url, token: token);
    if (!mounted) {
      api.close();
      return;
    }
    this._setState(() {
      _api = api;
      _activeServerUrl = url;
      _serverUrl.text = url;
      _status = 'تم استعادة إعداد الاتصال المحفوظ.';
      _error = null;
    });

    try {
      await api.checkConnection();
      await this._syncAndroidHealthToken(token);
      if (!mounted) return;
      this._setState(() => _connectionReady = true);
      await RhmServerUpdateNotifications.instance.prime(api);
      await this._loadProviders();
      await this._loadProjects();
      await this._restoreConversation();
      if (mounted) {
        this._setState(() {
          _connectionReady = true;
          _status = 'اتصال محلي بخادم RHM جاهز.';
          _error = null;
        });
        this._checkForUpdates(silent: true);
      }
    } on RhmApiException catch (error) {
      if (mounted) {
        this._setState(() {
          _connectionReady = false;
          _status = 'تم استعادة بيانات الاتصال، لكن الخادم لم يقبل الاتصال حاليًا.';
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        this._setState(() {
          _connectionReady = false;
          _status = 'الخادم غير متاح حاليًا؛ بيانات الاتصال ما زالت محفوظة.';
          _error = null;
        });
      }
    }
  }

  Future<void> this._verifyConnection() async {
    final api = _api;
    if (api == null || _checkingConnection) {
      if (api == null && mounted) {
        this._setState(() {
          _connectionReady = false;
          _status = 'أدخل إعدادات الاتصال أولًا.';
        });
      }
      return;
    }

    this._setState(() {
      _checkingConnection = true;
      _error = null;
      _status = 'جارٍ اختبار الاتصال بخادم RHM…';
    });
    try {
      await api.checkConnection();
      final savedToken = await _ChatScreenState._storage.read(key: _ChatScreenState._tokenKey);
      if (savedToken != null && savedToken.isNotEmpty) {
        await this._syncAndroidHealthToken(savedToken);
      }
      if (!mounted) return;
      this._setState(() {
        _connectionReady = true;
        _status = 'الاتصال بخادم RHM يعمل بصورة سليمة.';
        _error = null;
      });
      await this._loadProviders();
      await this._loadProjects();
    } on RhmApiException catch (error) {
      if (!mounted) return;
      this._setState(() {
        _connectionReady = false;
        _status = 'فشل اختبار الاتصال. إعداداتك المحفوظة لم تُحذف.';
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      this._setState(() {
        _connectionReady = false;
        _status = 'تعذر اختبار الاتصال. إعداداتك المحفوظة لم تُحذف.';
        _error = 'تحقق من تشغيل FastAPI على 127.0.0.1:8000.';
      });
    } finally {
      if (mounted) this._setState(() => _checkingConnection = false);
    }
  }

  Future<void> this._showConnectionSettings() async {
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
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: _busy ? null : () => this._connect(context, setDialogState),
              child: Text(_busy ? 'جارٍ التحقق…' : 'تحقق واتصل'),
            ),
          ],
        ),
      ),
    );
    if (mounted) _token.clear();
    if (connected == false && mounted && _api == null) {
      this._setState(() => _status = 'لم يتم الاتصال. يمكنك الكتابة بعد إعداد الخادم.');
    }
  }

  Future<void> this._connect(
    BuildContext dialogContext,
    void Function(void Function()) setDialogState,
  ) async {
    var connected = false;
    setDialogState(() {
      _busy = true;
      _error = null;
    });
    this._setState(() {
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
        await this._syncAndroidHealthToken(enteredToken);
        final previous = _api;
        _api = candidate;
        _activeServerUrl = requestedUrl;
        candidate = null;
        previous?.close();
      }

      if (!mounted || !dialogContext.mounted) return;
      _token.clear();
      this._setState(() {
        _connectionReady = true;
        _status = 'اتصال محلي بخادم RHM جاهز.';
        _error = null;
      });
      connected = true;
      await this._loadProviders();
      await this._loadProjects();
      await this._restoreConversation();
    } on RhmApiException catch (error) {
      if (dialogContext.mounted) setDialogState(() => _error = error.message);
      if (mounted) this._setState(() => _error = error.message);
    } catch (_) {
      if (dialogContext.mounted) {
        setDialogState(() => _error = 'تعذر الاتصال أو حفظ الإعدادات بأمان.');
      }
      if (mounted) this._setState(() => _error = 'تعذر الاتصال أو حفظ الإعدادات بأمان.');
    } finally {
      candidate?.close();
      if (mounted) {
        if (dialogContext.mounted) setDialogState(() => _busy = false);
        this._setState(() => _busy = false);
      }
    }
    if (connected && dialogContext.mounted) {
      Navigator.pop(dialogContext, true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) this._checkForUpdates(silent: true);
      });
    }
  }

  Future<void> this._loadProviders() async {
    if (_api == null) return;
    this._setState(() => _loadingProviders = true);
    try {
      final values = await _api!.getProviders();
      if (!mounted) return;
      this._setState(() {
        _providers = values;
        final matches = values.where((p) => p.provider == _preferredProvider && p.configured && p.models.isNotEmpty);
        if (matches.isEmpty) { _preferredProvider = null; _preferredModel = null; }
        else if (_preferredModel != null && !matches.first.models.contains(_preferredModel)) {
          _preferredModel = null;
        }
      });
    } on RhmApiException catch (e) { if (mounted) this._setState(() => _error = e.message); }
    finally { if (mounted) this._setState(() => _loadingProviders = false); }
  }

  Future<void> this._loadProjects() async {
    final api = _api;
    if (api == null) return;
    try {
      final projects = await api.listProjects();
      if (!mounted) return;
      this._setState(() {
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
      if (mounted) this._setState(() => _error = error.message);
    }
  }
}
