part of 'chat_screen.dart';

extension _ChatScreenConversations on _ChatScreenState {
  Future<void> _restoreConversation() async {
    final api = _api;
    if (api == null) return;
    this._setState(() => _loadingConversations = true);
    try {
      final savedId = await _ChatScreenState._storage.read(key: _ChatScreenState._conversationKey);
      final conversations = await api.listConversations();
      if (!mounted) return;
      final saved = conversations.where((item) => item.id == savedId);
      final selected = saved.isNotEmpty
          ? saved.first
          : (conversations.isNotEmpty ? conversations.first : null);
      this._setState(() => _conversations = conversations);
      if (selected == null) {
        this._setState(() {
          _conversationId = null;
          _conversationTitle = 'محادثة جديدة';
          _selectedProjectName = null;
          _projectScopeInitialized = false;
          _messages.clear();
          _hasOlderMessages = false;
          _nextMessageCursor = null;
        });
      } else {
        await _openConversation(selected, refreshList: false, force: true);
      }
      await _restorePendingTurn();
    } catch (error) {
      if (mounted) {
        this._setState(() => _error = error is RhmApiException
            ? error.message
            : 'تعذر استعادة سجل المحادثات.');
      }
    } finally {
      if (mounted) this._setState(() => _loadingConversations = false);
    }
  }

  Future<void> _refreshConversationList() async {
    final api = _api;
    if (api == null) return;
    try {
      final conversations = await api.listConversations();
      if (mounted) this._setState(() => _conversations = conversations);
    } catch (error) {
      if (mounted) {
        this._setState(() => _error = error is RhmApiException
            ? error.message
            : 'تعذر تحديث سجل المحادثات.');
      }
    }
  }

  Future<void> _openConversation(
    RhmConversation conversation, {
    bool refreshList = true,
    bool force = false,
  }) async {
    final api = _api;
    if (api == null || (_loadingConversations && !force)) return;
    if (!force &&
        _pendingRequestId != null &&
        _pendingConversationId != conversation.id) {
      final proceed = await _confirmDiscardPendingTurn('فتح محادثة أخرى');
      if (!proceed || !mounted) return;
    }
    this._setState(() {
      _loadingConversations = true;
      _error = null;
    });
    try {
      final page = await api.listConversationMessages(conversation.id);
      if (!mounted) return;
      await _ChatScreenState._storage.write(key: _ChatScreenState._conversationKey, value: conversation.id);
      this._setState(() {
        _conversationId = conversation.id;
        _conversationTitle = conversation.title;
        _selectedProjectName = conversation.projectName;
        _projectScopeInitialized = conversation.projectScopeInitialized;
        _messages
          ..clear()
          ..addAll(page.items.map((item) => RhmChatMessage(
                item.role == 'user',
                item.content,
                provider: item.provider == null
                    ? null
                    : '${item.provider} · ${item.model ?? ''}',
              )));
        _hasOlderMessages = page.hasMore;
        _nextMessageCursor = page.nextBefore;
      });
      if (refreshList) await _refreshConversationList();
      _scrollToLatest();
    } catch (error) {
      if (mounted) {
        this._setState(() => _error = error is RhmApiException
            ? error.message
            : 'تعذر فتح المحادثة المحفوظة.');
      }
    } finally {
      if (mounted) this._setState(() => _loadingConversations = false);
    }
  }

  Future<void> _newConversation() async {
    final api = _api;
    if (_pendingRequestId != null) {
      final proceed = await _confirmDiscardPendingTurn('بدء محادثة جديدة');
      if (!proceed || !mounted) return;
    }
    if (api == null) {
      await _showConnectionSettings();
      return;
    }
    try {
      final conversation = await api.createConversation();
      if (!mounted) return;
      await _ChatScreenState._storage.write(key: _ChatScreenState._conversationKey, value: conversation.id);
      this._setState(() {
        _conversationId = conversation.id;
        _conversationTitle = conversation.title;
        _selectedProjectName = null;
        _projectScopeInitialized = false;
        _messages.clear();
        _hasOlderMessages = false;
        _nextMessageCursor = null;
        _error = null;
        _status = 'بدأت محادثة جديدة.';
      });
      await _refreshConversationList();
    } catch (error) {
      if (mounted) {
        this._setState(() => _error = error is RhmApiException
            ? error.message
            : 'تعذر إنشاء محادثة جديدة.');
      }
    }
  }

  Future<void> _renameConversation(RhmConversation conversation) async {
    final controller = TextEditingController(text: conversation.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعادة تسمية المحادثة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'عنوان المحادثة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;
    try {
      final renamed = await _api!.renameConversation(conversation.id, title);
      if (!mounted) return;
      if (_conversationId == renamed.id) {
        this._setState(() => _conversationTitle = renamed.title);
      }
      await _refreshConversationList();
    } catch (error) {
      if (mounted) {
        this._setState(() => _error = error is RhmApiException
            ? error.message
            : 'تعذر إعادة تسمية المحادثة.');
      }
    }
  }

  Future<void> _deleteConversation(RhmConversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المحادثة؟'),
        content: const Text('سيتم حذف المحادثة وجميع رسائلها نهائيًا من سجل RHM.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف المحادثة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api!.deleteConversation(conversation.id);
      if (!mounted) return;
      if (_pendingConversationId == conversation.id) {
        await _clearPendingTurn();
      }
      if (_conversationId == conversation.id) {
        await _ChatScreenState._storage.delete(key: _ChatScreenState._conversationKey);
        this._setState(() {
          _conversationId = null;
          _conversationTitle = 'محادثة جديدة';
          _selectedProjectName = null;
          _projectScopeInitialized = false;
          _messages.clear();
          _hasOlderMessages = false;
          _nextMessageCursor = null;
        });
      }
      await _refreshConversationList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المحادثة ورسائلها.')),
        );
      }
    } catch (error) {
      if (mounted) {
        this._setState(() => _error = error is RhmApiException
            ? error.message
            : 'تعذر حذف المحادثة.');
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    final api = _api;
    final id = _conversationId;
    final cursor = _nextMessageCursor;
    if (api == null || id == null || cursor == null || _loadingOlderMessages) return;

    // Preserve the visible message anchor while the next page is prepended.
    final previousPixels = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    final previousMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;

    this._setState(() => _loadingOlderMessages = true);
    try {
      final page = await api.listConversationMessages(
        id,
        before: cursor,
      );
      if (!mounted) return;
      this._setState(() {
        _messages.insertAll(
          0,
          page.items.map((item) => RhmChatMessage(
                item.role == 'user',
                item.content,
                provider: item.provider == null
                    ? null
                    : '${item.provider} · ${item.model ?? ''}',
              )),
        );
        _hasOlderMessages = page.hasMore;
        _nextMessageCursor = page.nextBefore;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final position = _scrollController.position;
        final insertedExtent = position.maxScrollExtent - previousMaxExtent;
        final target = (previousPixels + insertedExtent)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        position.jumpTo(target);
      });
    } catch (error) {
      if (mounted) {
        this._setState(() => _error = error is RhmApiException
            ? error.message
            : 'تعذر تحميل الرسائل الأقدم.');
      }
    } finally {
      if (mounted) this._setState(() => _loadingOlderMessages = false);
    }
  }

  Future<void> _sendMessage() async {
    final api = _api;
    final text = _prompt.text.trim();
    if (api == null) {
      await _showConnectionSettings();
      return;
    }
    if (text.isEmpty || _busy) return;
    if (_pendingRequestId != null &&
        (_pendingPrompt != text || _pendingConversationId != _conversationId)) {
      final proceed = await _confirmDiscardPendingTurn('إرسال رسالة مختلفة');
      if (!proceed || !mounted) return;
    }

    this._setState(() {
      _busy = true;
      _error = null;
      _status = 'جارٍ حفظ الرسالة وإرسالها إلى RHM…';
    });

    var pendingRequestId = _pendingRequestId;
    try {
      // Persist the exact composer content before creating a conversation or
      // sending network requests, so an app/process restart cannot lose it.
      _composerDraftTimer?.cancel();
      _composerDraftTimer = null;
      await _saveComposerDraft(text);
      if (!mounted) return;
      _prompt.clear();
      var conversationId = _conversationId;
      if (conversationId == null) {
        final conversation = await api.createConversation(
          title: text.length > 48 ? '${text.substring(0, 48)}…' : text,
        );
        conversationId = conversation.id;
        await _ChatScreenState._storage.write(key: _ChatScreenState._conversationKey, value: conversationId);
        if (!mounted) return;
        this._setState(() {
          _conversationId = conversationId;
          _conversationTitle = conversation.title;
        });
      } else if (_messages.isEmpty && _conversationTitle == 'محادثة جديدة') {
        final title = text.length > 48 ? '${text.substring(0, 48)}…' : text;
        final renamed = await api.renameConversation(conversationId, title);
        if (mounted) this._setState(() => _conversationTitle = renamed.title);
      }

      final activeConversationId = conversationId;
      if (!mounted) return;
      final isRetry = _pendingRequestId != null &&
          _pendingPrompt == text &&
          _pendingConversationId == activeConversationId;
      if (!isRetry || pendingRequestId == null) {
        pendingRequestId = const Uuid().v4();
        await _savePendingTurn(
          requestId: pendingRequestId,
          prompt: text,
          conversationId: activeConversationId,
          provider: _preferredProvider,
          model: _preferredModel,
          projectName: _selectedProjectName,
        );
      }

      if (!mounted) return;
      final existingLastUserMessage = _messages.isNotEmpty &&
          _messages.last.isUser &&
          _messages.last.text == text;
      final restoredCompletedTurn = isRetry &&
          _messages.length >= 2 &&
          _messages[_messages.length - 2].isUser &&
          _messages[_messages.length - 2].text == text &&
          !_messages.last.isUser;
      if (!isRetry || (!existingLastUserMessage && !restoredCompletedTurn)) {
        this._setState(() {
          _messages.add(RhmChatMessage(true, text));
          _status = 'تم حفظ رسالتك؛ ينتظر رد RHM…';
        });
      }
      _scrollToLatest();

      final turn = await api.sendConversationMessage(
        activeConversationId,
        text,
        requestId: pendingRequestId,
        projectName: isRetry ? _pendingProjectName : _selectedProjectName,
        preferredProvider: isRetry ? _pendingProvider : _preferredProvider,
        preferredModel: isRetry ? _pendingModel : _preferredModel,
      );
      if (!mounted) return;
      this._setState(() {
        final alreadyRenderedTurn = isRetry &&
            _messages.length >= 2 &&
            _messages[_messages.length - 2].isUser &&
            _messages[_messages.length - 2].text == text &&
            !_messages.last.isUser &&
            _messages.last.text == turn.assistantMessage.content;
        if (!alreadyRenderedTurn && (_messages.isEmpty || _messages.last.isUser || _messages.last.text != turn.assistantMessage.content)) {
          _messages.add(RhmChatMessage(
            false,
            turn.assistantMessage.content,
            provider: '${turn.assistantMessage.provider ?? 'RHM'} · ${turn.assistantMessage.model ?? ''}',
          ));
        }
        _status = turn.replayed
            ? 'استُعيد الرد السابق بأمان دون تكرار الرسالة.'
            : 'تم حفظ المحادثة والرد في سجل RHM.';
      });
      if (_prompt.text.trim().isEmpty) {
        await _clearComposerDraft();
      } else {
        await _persistComposerDraft(_prompt.text);
      }
      await _clearPendingTurn();
      _projectScopeInitialized = true;
      await _refreshConversationList();
      _scrollToLatest();
    } on RhmApiException catch (error) {
      if (mounted) {
        this._setState(() {
          _error = error.message;
          _status = 'لم نتأكد من اكتمال الرسالة. أعد المحاولة؛ سيُستخدم معرّف الطلب نفسه.';
          final draftToRestore = _prompt.text.trim().isEmpty ? text : _prompt.text;
          _prompt.value = TextEditingValue(
            text: draftToRestore,
            selection: TextSelection.collapsed(offset: draftToRestore.length),
          );
          _scheduleComposerDraftSave(draftToRestore);
        });
      }
    } catch (_) {
      if (mounted) {
        this._setState(() {
          _error = 'تعذر إكمال المحادثة. تحقق من اتصال الخادم ثم أعد المحاولة.';
          _status = 'احتفظ RHM بمعرّف الطلب لإعادة المحاولة دون تكرار.';
          final draftToRestore = _prompt.text.trim().isEmpty ? text : _prompt.text;
          _prompt.value = TextEditingValue(
            text: draftToRestore,
            selection: TextSelection.collapsed(offset: draftToRestore.length),
          );
          _scheduleComposerDraftSave(draftToRestore);
        });
      }
    } finally {
      if (mounted) this._setState(() => _busy = false);
    }
  }
}
