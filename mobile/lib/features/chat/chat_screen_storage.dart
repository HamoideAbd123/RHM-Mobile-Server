part of 'chat_screen.dart';

extension _ChatScreenStorage on _ChatScreenState {
  Future<void> _restoreAppPreferences() async {
    try {
      final provider = await _ChatScreenState._storage.read(key: _ChatScreenState._providerPreferenceKey);
      final model = await _ChatScreenState._storage.read(key: _ChatScreenState._modelPreferenceKey);
      final locale = await _ChatScreenState._storage.read(key: _ChatScreenState._voiceLocalePreferenceKey);
      final offline = await _ChatScreenState._storage.read(key: _ChatScreenState._offlineRecognitionPreferenceKey);
      if (!mounted) return;
      _setState(() {
        _preferredProvider = provider;
        _preferredModel = model;
        if (locale == 'ar-SA' || locale == 'en-US') _locale = locale!;
        _offlineRecognition = offline == 'true';
      });
    } catch (_) {
      if (mounted) {
        _setState(() => _error = 'تعذر استعادة تفضيلات التطبيق. لم تُحذف بيانات الاتصال.');
      }
    }
  }

  Future<void> _restoreComposerDraft() async {
    try {
      final draft = await _ChatScreenState._storage.read(key: _ChatScreenState._composerDraftKey);
      final projectName = await _ChatScreenState._storage.read(key: _ChatScreenState._composerDraftProjectKey);
      if (!mounted || draft == null || draft.isEmpty) return;
      _composerDraftProjectName = projectName == 'none' ? null : projectName;
      _prompt.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
      _setState(() {
        _status = 'استُعيدت مسودة رسالة لم تُرسل بعد.';
      });
    } catch (_) {
      if (mounted) _setState(() => _error = 'تعذر استعادة مسودة الرسالة المحفوظة.');
    }
  }

  Future<void> _saveComposerDraft(String text) async {
    await _ChatScreenState._storage.write(key: _ChatScreenState._composerDraftKey, value: text);
    await _ChatScreenState._storage.write(
      key: _ChatScreenState._composerDraftProjectKey,
      value: _selectedProjectName ?? 'none',
    );
    _composerDraftProjectName = _selectedProjectName;
  }

  Future<void> _clearComposerDraft() async {
    _composerDraftTimer?.cancel();
    _composerDraftTimer = null;
    await _ChatScreenState._storage.delete(key: _ChatScreenState._composerDraftKey);
    await _ChatScreenState._storage.delete(key: _ChatScreenState._composerDraftProjectKey);
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
        _setState(() => _error = 'تعذر حفظ مسودة الرسالة في التخزين الآمن.');
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
        await _ChatScreenState._storage.delete(key: _ChatScreenState._providerPreferenceKey);
        await _ChatScreenState._storage.delete(key: _ChatScreenState._modelPreferenceKey);
      } else {
        await _ChatScreenState._storage.write(key: _ChatScreenState._providerPreferenceKey, value: _preferredProvider);
        if (_preferredModel == null) {
          await _ChatScreenState._storage.delete(key: _ChatScreenState._modelPreferenceKey);
        } else {
          await _ChatScreenState._storage.write(key: _ChatScreenState._modelPreferenceKey, value: _preferredModel);
        }
      }
      await _ChatScreenState._storage.write(key: _ChatScreenState._voiceLocalePreferenceKey, value: _locale);
      await _ChatScreenState._storage.write(
        key: _ChatScreenState._offlineRecognitionPreferenceKey,
        value: _offlineRecognition ? 'true' : 'false',
      );
    } catch (_) {
      if (mounted) _setState(() => _error = 'تعذر حفظ تفضيلات التطبيق في التخزين الآمن.');
    }
  }

  Future<void> _restorePendingTurn() async {
    try {
      final requestId = await _ChatScreenState._storage.read(key: _ChatScreenState._pendingRequestIdKey);
      final prompt = await _ChatScreenState._storage.read(key: _ChatScreenState._pendingPromptKey);
      final conversationId = await _ChatScreenState._storage.read(key: _ChatScreenState._pendingConversationKey);
      final provider = await _ChatScreenState._storage.read(key: _ChatScreenState._pendingProviderKey) ?? 'auto';
      final model = await _ChatScreenState._storage.read(key: _ChatScreenState._pendingModelKey) ?? 'auto';
      final projectName = await _ChatScreenState._storage.read(key: _ChatScreenState._pendingProjectKey) ?? 'none';
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
      _setState(() {
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
      if (mounted) _setState(() => _error = 'تعذر استعادة مسودة الرسالة غير المكتملة.');
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
    await _ChatScreenState._storage.write(key: _ChatScreenState._pendingRequestIdKey, value: requestId);
    await _ChatScreenState._storage.write(key: _ChatScreenState._pendingPromptKey, value: prompt);
    await _ChatScreenState._storage.write(key: _ChatScreenState._pendingConversationKey, value: conversationId);
    await _ChatScreenState._storage.write(key: _ChatScreenState._pendingProviderKey, value: provider ?? 'auto');
    await _ChatScreenState._storage.write(key: _ChatScreenState._pendingModelKey, value: model ?? 'auto');
    await _ChatScreenState._storage.write(key: _ChatScreenState._pendingProjectKey, value: projectName ?? 'none');
    _pendingRequestId = requestId;
    _pendingPrompt = prompt;
    _pendingConversationId = conversationId;
    _pendingProvider = provider;
    _pendingModel = model;
    _pendingProjectName = projectName;
  }

  Future<void> _clearPendingTurn() async {
    await _ChatScreenState._storage.delete(key: _ChatScreenState._pendingRequestIdKey);
    await _ChatScreenState._storage.delete(key: _ChatScreenState._pendingPromptKey);
    await _ChatScreenState._storage.delete(key: _ChatScreenState._pendingConversationKey);
    await _ChatScreenState._storage.delete(key: _ChatScreenState._pendingProviderKey);
    await _ChatScreenState._storage.delete(key: _ChatScreenState._pendingModelKey);
    await _ChatScreenState._storage.delete(key: _ChatScreenState._pendingProjectKey);
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
