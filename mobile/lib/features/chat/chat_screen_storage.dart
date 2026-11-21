part of 'chat_screen.dart';

extension _ChatScreenStorage on _ChatScreenState {
  Future<void> _restoreAppPreferences() async {
    try {
      final provider = await _storage.read(key: _providerPreferenceKey);
      final model = await _storage.read(key: _modelPreferenceKey);
      final locale = await _storage.read(key: _voiceLocalePreferenceKey);
      final offline = await _storage.read(key: _offlineRecognitionPreferenceKey);
      if (!mounted) return;
      setState(() {
        _preferredProvider = provider;
        _preferredModel = model;
        if (locale == 'ar-SA' || locale == 'en-US') _locale = locale!;
        _offlineRecognition = offline == 'true';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر استعادة تفضيلات التطبيق. لم تُحذف بيانات الاتصال.');
      }
    }
  }

  Future<void> _restoreComposerDraft() async {
    try {
      final draft = await _storage.read(key: _composerDraftKey);
      final projectName = await _storage.read(key: _composerDraftProjectKey);
      if (!mounted || draft == null || draft.isEmpty) return;
      _composerDraftProjectName = projectName == 'none' ? null : projectName;
      _prompt.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
      setState(() {
        _status = 'استُعيدت مسودة رسالة لم تُرسل بعد.';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر استعادة مسودة الرسالة المحفوظة.');
    }
  }

  Future<void> _saveComposerDraft(String text) async {
    await _storage.write(key: _composerDraftKey, value: text);
    await _storage.write(
      key: _composerDraftProjectKey,
      value: _selectedProjectName ?? 'none',
    );
    _composerDraftProjectName = _selectedProjectName;
  }

  Future<void> _clearComposerDraft() async {
    _composerDraftTimer?.cancel();
    _composerDraftTimer = null;
    await _storage.delete(key: _composerDraftKey);
    await _storage.delete(key: _composerDraftProjectKey);
    _composerDraftProjectName = null;
  }

  void _scheduleComposerDraftSave(String text) {
    _composerDraftTimer?.cancel();
    _composerDraftTimer = Timer(const Duration(milliseconds: 500), () {
      _composerDraftTimer = null;
      unawaited(_persistComposerDraft(text));
    });
  }

  Future<void> _persistComposerDraft(String text) async {
    try {
      if (text.trim().isEmpty) {
        await _clearComposerDraft();
      } else {
        await _saveComposerDraft(text);
      }
    } catch (error) {
      debugPrint('RHM composer draft could not be saved: $error');
      if (mounted) {
        setState(() => _error = 'تعذر حفظ مسودة الرسالة في التخزين الآمن.');
      }
    }
  }

  Future<void> _flushComposerDraft() async {
    _composerDraftTimer?.cancel();
    _composerDraftTimer = null;
    await _persistComposerDraft(_prompt.text);
  }

  Future<void> _persistAppPreferences() async {
    try {
      if (_preferredProvider == null) {
        await _storage.delete(key: _providerPreferenceKey);
        await _storage.delete(key: _modelPreferenceKey);
      } else {
        await _storage.write(key: _providerPreferenceKey, value: _preferredProvider);
        if (_preferredModel == null) {
          await _storage.delete(key: _modelPreferenceKey);
        } else {
          await _storage.write(key: _modelPreferenceKey, value: _preferredModel);
        }
      }
      await _storage.write(key: _voiceLocalePreferenceKey, value: _locale);
      await _storage.write(
        key: _offlineRecognitionPreferenceKey,
        value: _offlineRecognition ? 'true' : 'false',
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر حفظ تفضيلات التطبيق في التخزين الآمن.');
    }
  }

  Future<void> _restorePendingTurn() async {
    try {
      final requestId = await _storage.read(key: _pendingRequestIdKey);
      final prompt = await _storage.read(key: _pendingPromptKey);
      final conversationId = await _storage.read(key: _pendingConversationKey);
      final provider = await _storage.read(key: _pendingProviderKey) ?? 'auto';
      final model = await _storage.read(key: _pendingModelKey) ?? 'auto';
      final projectName = await _storage.read(key: _pendingProjectKey) ?? 'none';
      if (!mounted || requestId == null || prompt == null || conversationId == null) {
        return;
      }
      if (conversationId != _conversationId) {
        final pendingConversation = _conversations.where((item) => item.id == conversationId);
        if (pendingConversation.isEmpty) {
          await _clearPendingTurn();
          return;
        }
        await _openConversation(
          pendingConversation.first,
          refreshList: false,
          force: true,
        );
      }
      if (!mounted || conversationId != _conversationId) return;
      setState(() {
        _pendingRequestId = requestId;
        _pendingPrompt = prompt;
        _pendingConversationId = conversationId;
        _pendingProvider = provider == 'auto' ? null : provider;
        _pendingModel = model == 'auto' ? null : model;
        _pendingProjectName = projectName == 'none' ? null : projectName;
        _selectedProjectName = _pendingProjectName;
        _prompt.value = TextEditingValue(
          text: prompt,
          selection: TextSelection.collapsed(offset: prompt.length),
        );
        _status = 'هناك رسالة لم يكتمل تأكيد إرسالها. أعد إرسالها لاستخدام نفس الطلب دون تكرار.';
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر استعادة مسودة الرسالة غير المكتملة.');
    }
  }

  Future<void> _savePendingTurn({
    required String requestId,
    required String prompt,
    required String conversationId,
    required String? provider,
    required String? model,
    required String? projectName,
  }) async {
    await _storage.write(key: _pendingRequestIdKey, value: requestId);
    await _storage.write(key: _pendingPromptKey, value: prompt);
    await _storage.write(key: _pendingConversationKey, value: conversationId);
    await _storage.write(key: _pendingProviderKey, value: provider ?? 'auto');
    await _storage.write(key: _pendingModelKey, value: model ?? 'auto');
    await _storage.write(key: _pendingProjectKey, value: projectName ?? 'none');
    _pendingRequestId = requestId;
    _pendingPrompt = prompt;
    _pendingConversationId = conversationId;
    _pendingProvider = provider;
    _pendingModel = model;
    _pendingProjectName = projectName;
  }

  Future<void> _clearPendingTurn() async {
    await _storage.delete(key: _pendingRequestIdKey);
    await _storage.delete(key: _pendingPromptKey);
    await _storage.delete(key: _pendingConversationKey);
    await _storage.delete(key: _pendingProviderKey);
    await _storage.delete(key: _pendingModelKey);
    await _storage.delete(key: _pendingProjectKey);
    _pendingRequestId = null;
    _pendingPrompt = null;
    _pendingConversationId = null;
    _pendingProvider = null;
    _pendingModel = null;
    _pendingProjectName = null;
  }

  Future<bool> _confirmDiscardPendingTurn(String action) async {
    if (_pendingRequestId == null) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('هناك رسالة غير مكتملة'),
        content: Text(
          'توجد رسالة لم يؤكد RHM اكتمالها. ابدأ $action مع تجاهل مسودة إعادة المحاولة؟ '
          'قد تكون الرسالة وصلت إلى الخادم بالفعل؛ وسيظل أي دور محفوظ ظاهرًا في سجل المحادثة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('العودة لإعادة المحاولة'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تجاهل المسودة والمتابعة'),
          ),
        ],
      ),
    );
    if (discard != true) return false;
    await _clearPendingTurn();
    return true;
  }
}
