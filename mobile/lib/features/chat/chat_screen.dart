import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import '../../api_client.dart';
import '../../app_version_footer.dart';
import '../../conversation/chat_composer.dart';
import '../../conversation/chat_message_bubble.dart';
import '../../conversation/chat_message.dart';
import '../../conversation/suggestion_chip.dart';
import '../../android_runtime_bridge.dart';
import '../../update_service.dart';
import '../../server_update_notifications.dart';
import '../../server_update_screen.dart';
import '../../notifications_screen.dart';
import '../../control_center_screen.dart';
import '../../android_runtime_screen.dart';
import '../../mcp_screen.dart';
import '../../legacy_material_compatibility.dart';
import '../../more_tab_availability.dart';
import '../../settings_screen.dart';
import '../../workspace_screens.dart';
import '../../rhm_primary_navigation.dart';
import '../../rhm_theme.dart';

part 'chat_screen_storage.dart';
part 'chat_screen_updates.dart';
part 'chat_screen_connection.dart';
part 'chat_screen_conversations.dart';
part 'chat_screen_voice.dart';
part 'chat_screen_navigation.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const _serverKey = 'rhm_server_url';
  static const _tokenKey = 'rhm_mobile_token';
  static const _providerPreferenceKey = 'rhm_preferred_provider';
  static const _modelPreferenceKey = 'rhm_preferred_model';
  static const _voiceLocalePreferenceKey = 'rhm_voice_locale';
  static const _offlineRecognitionPreferenceKey = 'rhm_offline_recognition';
  static const _conversationKey = 'rhm_active_conversation_id';
  static const _pendingRequestIdKey = 'rhm_pending_request_id';
  static const _pendingPromptKey = 'rhm_pending_prompt';
  static const _pendingConversationKey = 'rhm_pending_conversation_id';
  static const _pendingProviderKey = 'rhm_pending_provider';
  static const _pendingModelKey = 'rhm_pending_model';
  static const _pendingProjectKey = 'rhm_pending_project';
  static const _composerDraftKey = 'rhm_composer_draft';
  static const _composerDraftProjectKey = 'rhm_composer_draft_project';
  static final _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: true,
      migrateWithBackup: true,
    ),
  );

  final _prompt = TextEditingController();
  final _conversationSearch = TextEditingController();
  final _serverUrl = TextEditingController();
  final _token = TextEditingController();
  final _scrollController = ScrollController();
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  final List<RhmChatMessage> _messages = [];
  List<RhmConversation> _conversations = [];
  String? _conversationId;
  String _conversationTitle = 'محادثة جديدة';
  bool _loadingConversations = false;
  bool _loadingOlderMessages = false;
  bool _hasOlderMessages = false;
  String? _nextMessageCursor;
  String? _pendingRequestId;
  String? _pendingPrompt;
  String? _pendingConversationId;
  String? _pendingProvider;
  String? _pendingModel;
  String? _pendingProjectName;
  String? _composerDraftProjectName;

  RhmApiClient? _api;
  String? _activeServerUrl;
  String _locale = 'ar-SA';
  String _status = 'اتصل بخادم RHM المحلي للبدء.';
  String? _error;
  String _voiceBase = '';
  bool _busy = false;
  bool _listening = false;
  bool _speechInitialized = false;
  bool _offlineRecognition = false;
  bool _speaking = false;
  List<RhmProviderInfo> _providers = [];
  String? _preferredProvider;
  String? _preferredModel;
  List<RhmProject> _projects = [];
  String? _selectedProjectName;
  bool _projectScopeInitialized = false;
  bool _loadingProviders = false;
  bool _checkingUpdate = false;
  bool _checkingConnection = false;
  bool _connectionReady = false;
  int _selectedDestination = 0;
  int _unreadNotifications = 0;
  static const _updateCheckInterval = Duration(hours: 6);
  Timer? _updateTimer;
  Timer? _serverNotificationTimer;
  Timer? _composerDraftTimer;
  DateTime? _lastUpdateCheckAt;

  void _this._setState(VoidCallback callback) {
    if (!mounted) return;
    this._setState(callback);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts.setStartHandler(() {
      if (mounted) this._setState(() => _speaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) this._setState(() => _speaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) this._setState(() => _speaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) {
        this._setState(() {
          _speaking = false;
          _error = 'تعذر تشغيل القراءة الصوتية. تحقق من محرك الصوت واللغة المثبتة.';
        });
      }
    });
    _serverUrl.text = RhmApiClient.defaultServerUrl;
    _bootstrap();
    _updateTimer = Timer.periodic(_updateCheckInterval, (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _checkForUpdates(silent: true);
      }
    });
    _serverNotificationTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _pollServerUpdateNotifications(),
    );
    unawaited(RhmServerUpdateNotifications.instance.initialize());
  }



















  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateTimer?.cancel();
    _serverNotificationTimer?.cancel();
    _composerDraftTimer?.cancel();
    _composerDraftTimer = null;
    unawaited(_persistComposerDraft(_prompt.text));
    _api?.close();
    _prompt.dispose();
    _conversationSearch.dispose();
    _serverUrl.dispose();
    _token.dispose();
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }





  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushComposerDraft());
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    _pollServerUpdateNotifications();
    final lastCheck = _lastUpdateCheckAt;
    if (lastCheck == null ||
        DateTime.now().difference(lastCheck) >= _updateCheckInterval) {
      _checkForUpdates(silent: true);
    }
  }





























































  Widget _buildConnectionRequiredScreen(String destination) => Scaffold(
        appBar: AppBar(title: Text(destination)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.link_off_rounded,
                  size: 42,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 14),
                const Text(
                  'اتصل بخادم RHM لفتح هذه المساحة.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _showConnectionSettings,
                  icon: const Icon(Icons.settings_ethernet_rounded),
                  label: const Text('إعداد الاتصال'),
                ),
              ],
            ),
          ),
        ),
      );

                  overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'مركز الإشعارات',
              onPressed: !_connectionReady ? null : () => _openWorkspace('notifications'),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded),
                  if (_unreadNotifications > 0)
                    Positioned(
                      top: -7,
                      right: -8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'اختبار اتصال RHM',
              onPressed: _checkingConnection ? null : _verifyConnection,
              icon: _checkingConnection
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering_rounded),
            ),
            IconButton(
              tooltip: 'التحقق من تحديث RHM',
              onPressed: _checkingUpdate ? null : () => _checkForUpdates(),
              icon: _checkingUpdate
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_alt_rounded),
            ),
            IconButton(
              tooltip: 'إعدادات RHM',
              onPressed: () => _openWorkspace('settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
            const SizedBox(width: 6),
          ],
        ) : null,
        bottomNavigationBar: keyboardVisible
            ? null
            : isWide
                ? const RhmAppVersionFooter()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RhmPrimaryNavigation(
                        selectedIndex: _selectedDestination,
                        onDestinationSelected: (index) =>
                            this._setState(() => _selectedDestination = index),
                      ),
                      const RhmAppVersionFooter(),
                    ],
                  ),
        body: Row(
          children: [
            if (isWide)
              RhmPrimaryNavigation(
                selectedIndex: _selectedDestination,
                useRail: true,
                onDestinationSelected: (index) => this._setState(() => _selectedDestination = index),
              ),
            Expanded(
              child: IndexedStack(
                index: _selectedDestination,
                children: [
                  SafeArea(
                    child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _error != null
                                ? Theme.of(context).colorScheme.error
                                : _connectionReady
                                    ? Theme.of(context).extension<RhmUiTokens>()!.success
                                    : Theme.of(context).extension<RhmUiTokens>()!.warning,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error ?? _status,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _error == null
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_connectionReady)
                          RhmMcpStatusChip(
                            api: _api,
                            onPressed: () => _openWorkspace('mcp'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  interactive: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(12),
                  itemCount: (_messages.isEmpty ? 1 : _messages.length) + (_hasOlderMessages ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_hasOlderMessages && index == 0) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: _loadingOlderMessages ? null : _loadOlderMessages,
                          icon: _loadingOlderMessages
                              ? const SizedBox.square(dimension: 15, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.history),
                          label: Text(_loadingOlderMessages ? 'جارٍ تحميل الأقدم…' : 'تحميل الرسائل الأقدم'),
                        ),
                      );
                    }
                    final messageIndex = index - (_hasOlderMessages ? 1 : 0);
                    if (_messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).extension<RhmUiTokens>()!.accentSoft,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Icon(
                                  Icons.forum_rounded,
                                  size: 36,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'أهلًا بك في RHM',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'أنا مساعدك الشخصي. اسألني، خطّط لمشاريعك، أو ابدأ محادثة صوتية.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.7,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  RhmSuggestionChip(label: 'خطّط ليومي', icon: Icons.today_rounded, onTap: () => useSuggestion('ساعدني في تنظيم يومي.')),
                                  RhmSuggestionChip(label: 'طوّر مشروعي', icon: Icons.code_rounded, onTap: () => useSuggestion('ساعدني في تطوير مشروعي خطوة بخطوة.')),
                                  RhmSuggestionChip(label: 'تعلّم شيئًا', icon: Icons.school_rounded, onTap: () => useSuggestion('اقترح لي درسًا عمليًا أتعلمه اليوم.')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final message = _messages[messageIndex];
                    return RhmChatMessageBubble(
                      message: message,
                      textDirection: _directionFor(message.text),
                      onSpeak: message.isUser ? null : () => speakResponse(message.text),
                      onCopy: () => copyMessage(message.text),
                    );
                  },
                  ),
                ),
              ),
              RhmChatComposer(
                controller: _prompt,
                projects: _projects,
                selectedProjectName: _selectedProjectName,
                projectScopeInitialized: _projectScopeInitialized,
                hasPendingRequest: _pendingRequestId != null,
                isBusy: _busy,
                isListening: _listening,
                isSpeaking: _speaking,
                onProjectChanged: (value) {
                  this._setState(() => _selectedProjectName = value);
                  _scheduleComposerDraftSave(_prompt.text);
                },
                onTextChanged: _scheduleComposerDraftSave,
                directionFor: _directionFor,
                onToggleRecording: toggleRecording,
                onSend: _sendMessage,
                onStopSpeaking: stopSpeaking,
              ),
            ],
          ),
                  ),
                  !shouldShowMoreServerModules(
                    hasApiClient: _api != null,
                    connectionReady: _connectionReady,
                  )
                      ? _buildConnectionRequiredScreen('المشاريع')
                      : RhmProjectsScreen(api: _api!),
                  _buildActivityTab(),
                  _buildMoreTab(),
                ],
              ),
            ),
          ],
        ),
      );
  }
}

