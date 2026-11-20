import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'update_service.dart';
import 'server_update_notifications.dart';
import 'server_update_screen.dart';
import 'notifications_screen.dart';
import 'control_center_screen.dart';
import 'mcp_screen.dart';
import 'legacy_material_compatibility.dart';
import 'markdown_table_theme.dart';
import 'more_tab_availability.dart';
import 'settings_screen.dart';
import 'workspace_screens.dart';
import 'rhm_primary_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeRhmBackgroundNotifications();
  runApp(const RhmApp());
}

class RhmApp extends StatelessWidget {
  const RhmApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RHM',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff159b72),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xfff7f8fc),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xfff7f8fc),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: Color(0xffe6e9f2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: Color(0xff159b72), width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        builder: (context, child) => wrapLegacyMaterialWidgets(child!),
        home: const Directionality(textDirection: TextDirection.rtl, child: ChatScreen()),
      );
}

class _ChatMessage {
  const _ChatMessage(this.isUser, this.text, {this.provider});

  final bool isUser;
  final String text;
  final String? provider;
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        onPressed: onTap,
        avatar: Icon(icon, size: 17, color: const Color(0xff159b72)),
        label: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xff3b4662))),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xffe2e7f3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

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
  final List<_ChatMessage> _messages = [];
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
  DateTime? _lastUpdateCheckAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts.setStartHandler(() {
      if (mounted) setState(() => _speaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) {
        setState(() {
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

  Future<void> _bootstrap() async {
    await _restoreAppPreferences();
    await _restoreComposerDraft();
    if (!mounted) return;
    await _restoreConnection();
  }

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
    await _storage.delete(key: _composerDraftKey);
    await _storage.delete(key: _composerDraftProjectKey);
    _composerDraftProjectName = null;
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateTimer?.cancel();
    _serverNotificationTimer?.cancel();
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

  Future<void> _checkForUpdates({bool silent = false}) async {
    if (_checkingUpdate) return;
    final api = _api;
    if (api == null) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اتصل بخادم RHM أولاً لإتاحة فحص التحديثات الآمن.'),
          ),
        );
      }
      return;
    }
    setState(() => _checkingUpdate = true);
    final updater = RhmUpdateService();
    try {
      final update = await updater.checkForUpdate(api);
      _lastUpdateCheckAt = DateTime.now();
      if (!mounted) return;
      if (update == null) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تطبيق RHM محدّث إلى آخر إصدار.')),
          );
        }
        return;
      }

      final publishedDate = update.publishedAt == null
          ? 'غير متاح'
          : update.publishedAt!.toLocal().toString().split(' ').first;
      final sizeMb = (update.apkSize / (1024 * 1024)).toStringAsFixed(1);
      final notes = update.releaseNotes.trim();
      final install = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('يتوفر تحديث جديد لـ RHM'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('الإصدار: ${update.version}'),
                  Text('تاريخ النشر: $publishedDate'),
                  Text('حجم التنزيل: $sizeMb MB'),
                  const Divider(height: 24),
                  const Text(
                    'ما الجديد؟',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    notes.isEmpty ? 'لم يرفق المطور سجل تغييرات لهذا الإصدار.' : notes,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'سيتم التحقق من SHA-256 قبل فتح مثبت Android. يجب الموافقة على التثبيت من نافذة Android.',
                    style: TextStyle(fontSize: 12, color: Color(0xff777f91)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('لاحقًا'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تنزيل وتثبيت'),
            ),
          ],
        ),
      );
      if (install != true || !mounted) return;
      await updater.downloadAndInstall(update, api);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التحقق من التحديث. أكمل التثبيت من نافذة Android.'),
          ),
        );
      }
    } on RhmApiException catch (error) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } on FormatException catch (error) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إكمال تحديث RHM. تحقق من أذونات تثبيت التطبيقات ومساحة التخزين.')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _pollServerUpdateNotifications() async {
    final api = _api;
    if (api == null || !_connectionReady ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    await RhmServerUpdateNotifications.instance.poll(api);
    try {
      final feed = await api.getNotifications(limit: 1);
      final preferences = feed['preferences'];
      final channels = preferences is Map<String, dynamic> &&
              preferences['channels'] is Map<String, dynamic>
          ? preferences['channels'] as Map<String, dynamic>
          : const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _unreadNotifications = channels['in_app'] == true &&
                feed['unread_count'] is int
            ? feed['unread_count'] as int
            : 0;
      });
    } catch (_) {
      // Notification badge failures must not affect chat or background notifications.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _pollServerUpdateNotifications();
    final lastCheck = _lastUpdateCheckAt;
    if (lastCheck == null ||
        DateTime.now().difference(lastCheck) >= _updateCheckInterval) {
      _checkForUpdates(silent: true);
    }
  }

  Future<void> _restoreConnection() async {
    String? savedUrl;
    String? token;
    try {
      savedUrl = await _storage.read(key: _serverKey);
      token = await _storage.read(key: _tokenKey);
    } catch (_) {
      // Never erase credentials as a side effect of a read/decryption error.
      // Keep the user on the chat screen and surface a recoverable warning.
      if (!mounted) return;
      setState(() {
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
      setState(() {
        _status = 'عنوان الخادم محفوظ؛ أدخل رمز الوصول مرة واحدة لإكمال الاتصال.';
      });
      return;
    }

    final api = RhmApiClient(serverUrl: url, token: token);
    if (!mounted) {
      api.close();
      return;
    }
    setState(() {
      _api = api;
      _activeServerUrl = url;
      _serverUrl.text = url;
      _status = 'تم استعادة إعداد الاتصال المحفوظ.';
      _error = null;
    });

    try {
      await api.checkConnection();
      if (!mounted) return;
      setState(() => _connectionReady = true);
      await RhmServerUpdateNotifications.instance.prime(api);
      await _loadProviders();
      await _loadProjects();
      await _restoreConversation();
      if (mounted) {
        setState(() {
          _connectionReady = true;
          _status = 'اتصال محلي بخادم RHM جاهز.';
          _error = null;
        });
        _checkForUpdates(silent: true);
      }
    } on RhmApiException catch (error) {
      if (mounted) {
        setState(() {
          _connectionReady = false;
          _status = 'تم استعادة بيانات الاتصال، لكن الخادم لم يقبل الاتصال حاليًا.';
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
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
        setState(() {
          _connectionReady = false;
          _status = 'أدخل إعدادات الاتصال أولًا.';
        });
      }
      return;
    }

    setState(() {
      _checkingConnection = true;
      _error = null;
      _status = 'جارٍ اختبار الاتصال بخادم RHM…';
    });
    try {
      await api.checkConnection();
      if (!mounted) return;
      setState(() {
        _connectionReady = true;
        _status = 'الاتصال بخادم RHM يعمل بصورة سليمة.';
        _error = null;
      });
      await _loadProviders();
      await _loadProjects();
    } on RhmApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _connectionReady = false;
        _status = 'فشل اختبار الاتصال. إعداداتك المحفوظة لم تُحذف.';
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connectionReady = false;
        _status = 'تعذر اختبار الاتصال. إعداداتك المحفوظة لم تُحذف.';
        _error = 'تحقق من تشغيل FastAPI على 127.0.0.1:8000.';
      });
    } finally {
      if (mounted) setState(() => _checkingConnection = false);
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
      setState(() => _status = 'لم يتم الاتصال. يمكنك الكتابة بعد إعداد الخادم.');
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
    setState(() {
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
        await _storage.write(key: _serverKey, value: requestedUrl);
        await _storage.write(key: _tokenKey, value: enteredToken);
        final previous = _api;
        _api = candidate;
        _activeServerUrl = requestedUrl;
        candidate = null;
        previous?.close();
      }

      if (!mounted || !dialogContext.mounted) return;
      _token.clear();
      setState(() {
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
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (dialogContext.mounted) {
        setDialogState(() => _error = 'تعذر الاتصال أو حفظ الإعدادات بأمان.');
      }
      if (mounted) setState(() => _error = 'تعذر الاتصال أو حفظ الإعدادات بأمان.');
    } finally {
      candidate?.close();
      if (mounted) {
        if (dialogContext.mounted) setDialogState(() => _busy = false);
        setState(() => _busy = false);
      }
    }
    if (connected && dialogContext.mounted) {
      Navigator.pop(dialogContext, true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkForUpdates(silent: true);
      });
    }
  }

  Future<void> _loadProviders() async {
    if (_api == null) return;
    setState(() => _loadingProviders = true);
    try {
      final values = await _api!.getProviders();
      if (!mounted) return;
      setState(() {
        _providers = values;
        final matches = values.where((p) => p.provider == _preferredProvider && p.configured && p.models.isNotEmpty);
        if (matches.isEmpty) { _preferredProvider = null; _preferredModel = null; }
        else if (_preferredModel != null && !matches.first.models.contains(_preferredModel)) {
          _preferredModel = null;
        }
      });
    } on RhmApiException catch (e) { if (mounted) setState(() => _error = e.message); }
    finally { if (mounted) setState(() => _loadingProviders = false); }
  }
  Future<void> _loadProjects() async {
    final api = _api;
    if (api == null) return;
    try {
      final projects = await api.listProjects();
      if (!mounted) return;
      setState(() {
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
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _restoreConversation() async {
    final api = _api;
    if (api == null) return;
    setState(() => _loadingConversations = true);
    try {
      final savedId = await _storage.read(key: _conversationKey);
      final conversations = await api.listConversations();
      if (!mounted) return;
      final saved = conversations.where((item) => item.id == savedId);
      final selected = saved.isNotEmpty
          ? saved.first
          : (conversations.isNotEmpty ? conversations.first : null);
      setState(() => _conversations = conversations);
      if (selected == null) {
        setState(() {
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
        setState(() => _error = error is RhmApiException
            ? error.message
            : 'تعذر استعادة سجل المحادثات.');
      }
    } finally {
      if (mounted) setState(() => _loadingConversations = false);
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

  Future<void> _refreshConversationList() async {
    final api = _api;
    if (api == null) return;
    try {
      final conversations = await api.listConversations();
      if (mounted) setState(() => _conversations = conversations);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is RhmApiException
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
    setState(() {
      _loadingConversations = true;
      _error = null;
    });
    try {
      final page = await api.listConversationMessages(conversation.id);
      if (!mounted) return;
      await _storage.write(key: _conversationKey, value: conversation.id);
      setState(() {
        _conversationId = conversation.id;
        _conversationTitle = conversation.title;
        _selectedProjectName = conversation.projectName;
        _projectScopeInitialized = conversation.projectScopeInitialized;
        _messages
          ..clear()
          ..addAll(page.items.map((item) => _ChatMessage(
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
        setState(() => _error = error is RhmApiException
            ? error.message
            : 'تعذر فتح المحادثة المحفوظة.');
      }
    } finally {
      if (mounted) setState(() => _loadingConversations = false);
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
      await _storage.write(key: _conversationKey, value: conversation.id);
      setState(() {
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
        setState(() => _error = error is RhmApiException
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
        setState(() => _conversationTitle = renamed.title);
      }
      await _refreshConversationList();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is RhmApiException
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
        await _storage.delete(key: _conversationKey);
        setState(() {
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
        setState(() => _error = error is RhmApiException
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

    setState(() => _loadingOlderMessages = true);
    try {
      final page = await api.listConversationMessages(
        id,
        before: cursor,
      );
      if (!mounted) return;
      setState(() {
        _messages.insertAll(
          0,
          page.items.map((item) => _ChatMessage(
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
        setState(() => _error = error is RhmApiException
            ? error.message
            : 'تعذر تحميل الرسائل الأقدم.');
      }
    } finally {
      if (mounted) setState(() => _loadingOlderMessages = false);
    }
  }

  Future<void> _openWorkspace(String section, {bool closeDrawer = false}) async {
    if (closeDrawer) Navigator.pop(context);

    // Settings are a local application surface and must remain usable offline.
    if (section == 'settings') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RhmSettingsScreen(
            serverUrl: _activeServerUrl ?? _serverUrl.text,
            connectionReady: _connectionReady,
            providers: _providers,
            preferredProvider: _preferredProvider,
            preferredModel: _preferredModel,
            locale: _locale,
            offlineRecognition: _offlineRecognition,
            onOpenConnectionSettings: _showConnectionSettings,
            onOpenVoiceDiagnostics: () => _openWorkspace('voice'),
            onCheckAppUpdates: () => _checkForUpdates(),
            onRefreshProviders: _connectionReady ? _loadProviders : null,
            onProviderChanged: (value) {
              setState(() {
                _preferredProvider = value;
                _preferredModel = null;
              });
              _persistAppPreferences();
            },
            onModelChanged: (value) {
              setState(() => _preferredModel = value);
              _persistAppPreferences();
            },
            onLocaleChanged: (value) {
              setState(() => _locale = value);
              _persistAppPreferences();
            },
            onOfflineRecognitionChanged: (value) {
              setState(() => _offlineRecognition = value);
              _persistAppPreferences();
            },
          ),
        ),
      );
      return;
    }

    final api = _api;
    if (api == null) {
      await _showConnectionSettings();
      return;
    }
    final Widget screen = switch (section) {
      'projects' => RhmProjectsScreen(api: api),
      'tasks' => RhmTasksScreen(api: api),
      'memories' => RhmMemoriesScreen(api: api),
      'audit' => RhmAuditScreen(api: api),
      'devices' => RhmDevicesScreen(api: api),
      'control' => RhmControlCenterScreen(
          api: api,
          tts: _tts,
          speech: _speech,
          locale: _locale,
          preferredProvider: _preferredProvider,
          preferredModel: _preferredModel,
        ),
      'server-update' => RhmServerUpdateScreen(api: api),
      'mcp' => RhmMcpScreen(api: api),
      'notifications' => RhmNotificationsScreen(api: api),
      'voice' => RhmVoiceDiagnosticsScreen(
          tts: _tts,
          speech: _speech,
          locale: _locale,
        ),
      'agent' => RhmAgentScreen(
          api: api,
          preferredProvider: _preferredProvider,
          preferredModel: _preferredModel,
        ),
      _ => const SizedBox.shrink(),
    };
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _toggleRecording() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _listening = false;
          _status = 'تم إيقاف التسجيل. راجع النص قبل الإرسال.';
        });
      }
      return;
    }
    await _tts.stop();
    if (!mounted) return;
    List<LocaleName> matchingLocales;
    try {
      if (!_speechInitialized) {
        _speechInitialized = await _speech.initialize(
          onError: (_) {
            if (mounted) {
              setState(() {
                _listening = false;
                _error = _offlineRecognition
                    ? 'تعذر التعرف المحلي أو لم يُسمح بإذن الميكروفون.'
                    : 'تعذر التعرف على الكلام. تحقق من إذن الميكروفون وخدمات الصوت.';
              });
            }
          },
          onStatus: (status) {
            if (status == 'notListening' && mounted) {
              setState(() => _listening = false);
            }
          },
        );
      }
      if (!mounted) return;
      if (!_speechInitialized) {
        setState(() => _error = 'التعرف على الكلام غير متاح أو لم يُسمح بإذن الميكروفون.');
        return;
      }
      matchingLocales = await _speech.locales();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تهيئة خدمة التعرف أو قراءة اللغات المتاحة.');
      }
      return;
    }
    if (!mounted) return;
    final language = _locale.split('-').first.toLowerCase();
    final preferredLocale = _locale.toLowerCase().replaceAll('_', '-');
    matchingLocales = matchingLocales.where((item) {
      final id = item.localeId.toLowerCase().replaceAll('_', '-');
      return id == preferredLocale || id == language || id.startsWith('$language-');
    }).toList()
      ..sort((left, right) {
        final leftId = left.localeId.toLowerCase().replaceAll('_', '-');
        final rightId = right.localeId.toLowerCase().replaceAll('_', '-');
        return (leftId == preferredLocale ? 0 : 1)
            .compareTo(rightId == preferredLocale ? 0 : 1);
      });
    if (matchingLocales.isEmpty) {
      setState(() => _error = 'لغة $_locale غير متاحة في خدمة التعرف على هذا الجهاز.');
      return;
    }
    final match = matchingLocales.first;
    _voiceBase = _prompt.text.trim();
    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenOptions: SpeechListenOptions(
          localeId: match.localeId,
          onDevice: _offlineRecognition,
          partialResults: true,
          listenFor: const Duration(seconds: 30),
        ),
      );
      if (!mounted) return;
      setState(() {
        _listening = true;
        _error = null;
        _status = _offlineRecognition
            ? 'يحاول الجهاز التعرف محليًا؛ لن يتحول تلقائيًا إلى التعرف عبر الإنترنت.'
            : 'التعرف عبر خدمة الجهاز؛ قد يتطلب اتصالًا بحسب إعدادات Android.';
      });
    } catch (_) {
      setState(() {
        _listening = false;
        _error = _offlineRecognition
            ? 'التعرف المحلي غير متاح. ثبّت حزمة اللغة على الجهاز أو اختر التعرف عبر الإنترنت.'
            : 'تعذر بدء التسجيل. تحقق من إذن الميكروفون.';
      });
    }
  }

  void _useSuggestion(String value) {
    setState(() {
      _prompt.text = value;
      _prompt.selection = TextSelection.collapsed(offset: value.length);
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final recognized = result.recognizedWords.trim();
    final combined = [_voiceBase, recognized].where((part) => part.isNotEmpty).join(' ');
    _prompt.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );
    if (result.finalResult && mounted) {
      setState(() {
        _listening = false;
        _status = 'راجع النص وعدّله قبل إرساله.';
      });
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

    setState(() {
      _busy = true;
      _error = null;
      _status = 'جارٍ حفظ الرسالة وإرسالها إلى RHM…';
    });

    var pendingRequestId = _pendingRequestId;
    try {
      // Persist the exact composer content before creating a conversation or
      // sending network requests, so an app/process restart cannot lose it.
      await _saveComposerDraft(text);
      if (!mounted) return;
      _prompt.clear();
      var conversationId = _conversationId;
      if (conversationId == null) {
        final conversation = await api.createConversation(
          title: text.length > 48 ? '${text.substring(0, 48)}…' : text,
        );
        conversationId = conversation.id;
        await _storage.write(key: _conversationKey, value: conversationId);
        if (!mounted) return;
        setState(() {
          _conversationId = conversationId;
          _conversationTitle = conversation.title;
        });
      } else if (_messages.isEmpty && _conversationTitle == 'محادثة جديدة') {
        final title = text.length > 48 ? '${text.substring(0, 48)}…' : text;
        final renamed = await api.renameConversation(conversationId, title);
        if (mounted) setState(() => _conversationTitle = renamed.title);
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
        setState(() {
          _messages.add(_ChatMessage(true, text));
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
      setState(() {
        final alreadyRenderedTurn = isRetry &&
            _messages.length >= 2 &&
            _messages[_messages.length - 2].isUser &&
            _messages[_messages.length - 2].text == text &&
            !_messages.last.isUser &&
            _messages.last.text == turn.assistantMessage.content;
        if (!alreadyRenderedTurn && (_messages.isEmpty || _messages.last.isUser || _messages.last.text != turn.assistantMessage.content)) {
          _messages.add(_ChatMessage(
            false,
            turn.assistantMessage.content,
            provider: '${turn.assistantMessage.provider ?? 'RHM'} · ${turn.assistantMessage.model ?? ''}',
          ));
        }
        _status = turn.replayed
            ? 'استُعيد الرد السابق بأمان دون تكرار الرسالة.'
            : 'تم حفظ المحادثة والرد في سجل RHM.';
      });
      await _clearComposerDraft();
      await _clearPendingTurn();
      _projectScopeInitialized = true;
      await _refreshConversationList();
      _scrollToLatest();
    } on RhmApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _status = 'لم نتأكد من اكتمال الرسالة. أعد المحاولة؛ سيُستخدم معرّف الطلب نفسه.';
          _prompt.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذر إكمال المحادثة. تحقق من اتصال الخادم ثم أعد المحاولة.';
          _status = 'احتفظ RHM بمعرّف الطلب لإعادة المحاولة دون تكرار.';
          _prompt.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isOfflineVoice(Map<dynamic, dynamic> voice) {
    final requirement = voice['network_required'];
    return requirement == false ||
        requirement == 0 ||
        requirement == '0' ||
        requirement == 'false';
  }

  Future<void> _copyMessage(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ الرسالة.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر نسخ الرسالة على هذا الجهاز.')),
      );
    }
  }

  Future<void> _speakResponse(String text) async {
    await _speech.stop();
    if (!mounted) return;
    final language = _locale.split('-').first.toLowerCase();
    final preferredLocale = _locale.toLowerCase().replaceAll('_', '-');

    try {
      final dynamic rawVoices = await _tts.getVoices;
      if (!mounted) return;
      final voices = (rawVoices as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .where((voice) {
            final locale = voice['locale'];
            if (locale is! String) return false;
            final normalized = locale.toLowerCase().replaceAll('_', '-');
            return normalized == preferredLocale ||
                normalized == language ||
                normalized.startsWith('$language-');
          })
          .toList()
        ..sort((left, right) {
          final leftLocale = left['locale'].toString().toLowerCase().replaceAll('_', '-');
          final rightLocale = right['locale'].toString().toLowerCase().replaceAll('_', '-');
          return (leftLocale == preferredLocale ? 0 : 1)
              .compareTo(rightLocale == preferredLocale ? 0 : 1);
        });

      var usingOfflineVoice = false;
      if (voices.isEmpty) {
        final available = await _tts.isLanguageAvailable(_locale);
        if (available != true) {
          throw StateError('No voice available for the selected language.');
        }
        await _tts.setLanguage(_locale);
      } else {
        final offline = voices.where(_isOfflineVoice).toList();
        final selected = offline.isNotEmpty ? offline.first : voices.first;
        usingOfflineVoice = _isOfflineVoice(selected);
        await _tts.setVoice({
          'name': selected['name'].toString(),
          'locale': selected['locale'].toString(),
        });
      }

      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      if (!mounted) return;
      setState(() {
        _error = null;
        _status = usingOfflineVoice
            ? 'تتم قراءة الرد بصوت محلي مثبت على الجهاز.'
            : 'تتم قراءة الرد عبر محرك الصوت المتاح؛ قد يحتاج هذا الصوت إلى الإنترنت.';
      });
      final result = await _tts.speak(text, focus: true);
      if (result != 1 && mounted) {
        setState(() {
          _speaking = false;
          _error = 'لم يبدأ محرك الصوت القراءة. تحقق من إعدادات تحويل النص إلى كلام في Android.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _speaking = false;
          _error = 'لا يتوفر صوت مناسب للغة المختارة. ثبّت صوتًا عربيًا/إنجليزيًا من إعدادات Android أو غيّر محرك تحويل النص إلى كلام.';
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    if (mounted) setState(() => _speaking = false);
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  TextDirection _directionFor(String value) =>
      RegExp(r'[\u0600-\u06ff]').hasMatch(value) ? TextDirection.rtl : TextDirection.ltr;


  Widget _buildSidebar() {
    final available = _providers
        .where((provider) => provider.configured && provider.models.isNotEmpty)
        .toList();
    final selected = available.where((provider) => provider.provider == _preferredProvider);
    final models = selected.isEmpty ? <String>[] : selected.first.models;
    final query = _conversationSearch.text.trim().toLowerCase();
    final visibleConversations = _conversations.where((conversation) {
      if (query.isEmpty) return true;
      return conversation.title.toLowerCase().contains(query);
    }).toList();

    return Drawer(
      width: 320,
      child: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: Text(
                    'RHM  •  مساعدك الشخصي',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _newConversation();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('محادثة جديدة'),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 22, 18, 8),
                  child: Text(
                    'اختيار الذكاء الاصطناعي',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DropdownButtonFormField<String>(
                    initialValue: _preferredProvider,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'المزوّد'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('تلقائي حسب الخادم'),
                      ),
                      ...available.map(
                        (provider) => DropdownMenuItem<String>(
                          value: provider.provider,
                          child: Text(
                            provider.provider == 'gemini'
                                ? 'Google Gemini'
                                : provider.provider == 'ollama'
                                    ? 'Ollama محلي'
                                    : provider.provider,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _preferredProvider = value;
                        _preferredModel = null;
                      });
                      _persistAppPreferences();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: DropdownButtonFormField<String>(
                    initialValue: models.contains(_preferredModel)
                        ? _preferredModel
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'النموذج'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('اختيار تلقائي'),
                      ),
                      ...models.map(
                        (model) => DropdownMenuItem<String>(
                          value: model,
                          child: Text(model, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: _preferredProvider == null
                        ? null
                        : (value) {
                            setState(() => _preferredModel = value);
                            _persistAppPreferences();
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: _api == null || _loadingProviders
                        ? null
                        : _loadProviders,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      _loadingProviders ? 'جارٍ التحديث…' : 'تحديث النماذج',
                    ),
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, 6),
                  child: Text('سجل المحادثات', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: _conversationSearch,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'ابحث في المحادثات',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _conversationSearch.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'مسح البحث',
                              onPressed: () {
                                _conversationSearch.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      isDense: true,
                    ),
                  ),
                ),
                if (_loadingConversations && _conversations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (visibleConversations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                    child: Text(
                      _conversations.isEmpty
                          ? 'ستظهر محادثاتك المحفوظة هنا.'
                          : 'لا توجد محادثات تطابق البحث.',
                      style: const TextStyle(color: Color(0xff858da0), fontSize: 12),
                    ),
                  )
                else
                  ...visibleConversations.map((conversation) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.chat_bubble_outline, size: 19),
                    title: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: conversation.id == _conversationId ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: conversation.id == _conversationId,
                    onTap: () {
                      Navigator.pop(context);
                      _openConversation(conversation);
                    },
                    trailing: PopupMenuButton<String>(
                      tooltip: 'خيارات المحادثة',
                      onSelected: (value) {
                        if (value == 'rename') _renameConversation(conversation);
                        if (value == 'delete') _deleteConversation(conversation);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('إعادة تسمية')),
                        PopupMenuItem(value: 'delete', child: Text('حذف المحادثة')),
                      ],
                    ),
                  )),
                ListTile(
                  leading: const Icon(Icons.refresh, size: 19),
                  title: const Text('تحديث السجل'),
                  dense: true,
                  onTap: () {
                    _refreshConversationList();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('لوحة تحكم RHM'),
                  subtitle: const Text('حالة النظام والتطبيقات والوحدات'),
                  onTap: () => _openWorkspace('control', closeDrawer: true),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, 6),
                  child: Text('مساحة العمل', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('المشاريع'),
                  onTap: () => _openWorkspace('projects', closeDrawer: true),
                ),
                ListTile(
                  leading: const Icon(Icons.checklist),
                  title: const Text('المهام'),
                  onTap: () => _openWorkspace('tasks', closeDrawer: true),
                ),
                ListTile(
                  leading: const Icon(Icons.psychology_outlined),
                  title: const Text('الذاكرة'),
                  onTap: () => _openWorkspace('memories', closeDrawer: true),
                ),
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: const Text('وكيل RHM'),
                  subtitle: const Text('أدوات قراءة آمنة'),
                  onTap: () => _openWorkspace('agent', closeDrawer: true),
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('سجل التدقيق'),
                  onTap: () => _openWorkspace('audit', closeDrawer: true),
                ),
                ListTile(
                  leading: const Icon(Icons.devices_other_outlined),
                  title: const Text('الأجهزة المسجلة'),
                  onTap: () => _openWorkspace('devices', closeDrawer: true),
                ),
                ListTile(
                  leading: const Icon(Icons.hub_outlined),
                  title: const Text('تكاملات MCP'),
                  subtitle: const Text('خوادم MCP والأدوات المعتمدة'),
                  onTap: () => _openWorkspace('mcp', closeDrawer: true),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('مركز الإشعارات'),
                  subtitle: const Text('الدردشة والمهام والأجهزة والنظام'),
                  onTap: () => _openWorkspace('notifications', closeDrawer: true),
                ),
                ListTile(
                  leading: const Icon(Icons.system_update_alt),
                  title: const Text('إدارة تحديث السيرفر'),
                  subtitle: const Text('حالة السيرفر والتحديثات والإشعارات'),
                  onTap: () => _openWorkspace('server-update', closeDrawer: true),
                ),
                ListTile(
                  leading: const Icon(Icons.graphic_eq_rounded),
                  title: const Text('تشخيص الصوت'),
                  subtitle: const Text('محركات النطق والميكروفون واللغات'),
                  onTap: () => _openWorkspace('voice', closeDrawer: true),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text('المحادثة الحالية'),
                  selected: true,
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('إعدادات RHM'),
                  subtitle: const Text('الاتصال والتكاملات والتحديثات والصوت'),
                  onTap: () => _openWorkspace('settings', closeDrawer: true),
                ),
                if (_providers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _providers
                          .map((provider) => '${provider.provider}: ${provider.status}')
                          .join('\n'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionRequiredScreen(String destination) => Scaffold(
        appBar: AppBar(title: Text(destination)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off_rounded, size: 42, color: Color(0xff8a93a5)),
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

  Widget _hubTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          minVerticalPadding: 12,
          leading: CircleAvatar(
            backgroundColor: const Color(0xffe8f5f0),
            child: Icon(icon, color: const Color(0xff159b72)),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: onTap,
        ),
      );

  Widget _buildActivityTab() {
    if (_api == null) return _buildConnectionRequiredScreen('النشاط');
    return Scaffold(
      appBar: AppBar(title: const Text('النشاط')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'تابع العمل والتنبيهات والأحداث المهمة في RHM.',
            style: TextStyle(color: Color(0xff737b8e)),
          ),
          const SizedBox(height: 14),
          _hubTile(
            icon: Icons.checklist_rounded,
            title: 'المهام',
            subtitle: 'المهام المفتوحة وحالات التنفيذ والأولويات',
            onTap: () => _openWorkspace('tasks'),
          ),
          _hubTile(
            icon: Icons.notifications_active_outlined,
            title: 'الإشعارات',
            subtitle: 'تحديثات المحادثات والمهام والنظام',
            onTap: () => _openWorkspace('notifications'),
          ),
          _hubTile(
            icon: Icons.receipt_long_outlined,
            title: 'سجل التدقيق',
            subtitle: 'الأحداث والعمليات المسجلة في RHM',
            onTap: () => _openWorkspace('audit'),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreTab() {
    final showServerModules = shouldShowMoreServerModules(
      hasApiClient: _api != null,
      connectionReady: _connectionReady,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!showServerModules)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'بعض وحدات RHM تحتاج إلى اتصال بالخادم. يمكنك فتح الإعدادات حتى عندما يكون الخادم متوقفًا.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          _hubTile(
            icon: Icons.settings_outlined,
            title: 'إعدادات RHM',
            subtitle: 'الاتصال والمزوّد والصوت والتحديثات',
            onTap: () => _openWorkspace('settings'),
          ),
          if (showServerModules) ...[
            _hubTile(
              icon: Icons.psychology_outlined,
              title: 'الذاكرة',
              subtitle: 'استعراض الذكريات والبحث وإدارتها',
              onTap: () => _openWorkspace('memories'),
            ),
            _hubTile(
              icon: Icons.smart_toy_outlined,
              title: 'وكيل RHM والأدوات',
              subtitle: 'تشغيل الوكيل ومراجعة الأدوات المسموح بها',
              onTap: () => _openWorkspace('agent'),
            ),
            _hubTile(
              icon: Icons.devices_other_outlined,
              title: 'الأجهزة',
              subtitle: 'الأجهزة المسجلة وحالة اتصالها',
              onTap: () => _openWorkspace('devices'),
            ),
            _hubTile(
              icon: Icons.hub_outlined,
              title: 'تكاملات MCP',
              subtitle: 'خوادم MCP والأدوات المعتمدة والقراءة فقط',
              onTap: () => _openWorkspace('mcp'),
            ),
            _hubTile(
              icon: Icons.tune_rounded,
              title: 'مركز التحكم',
              subtitle: 'حالة النظام والتطبيقات والوحدات',
              onTap: () => _openWorkspace('control'),
            ),
            _hubTile(
              icon: Icons.system_update_alt_rounded,
              title: 'تحديثات الخادم',
              subtitle: 'حالة الخادم والتحديثات',
              onTap: () => _openWorkspace('server-update'),
            ),
            _hubTile(
              icon: Icons.graphic_eq_rounded,
              title: 'تشخيص الصوت',
              subtitle: 'محركات النطق والميكروفون واللغات',
              onTap: () => _openWorkspace('voice'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
        drawer: _buildSidebar(),
        appBar: _selectedDestination == 0 ? AppBar(
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff20b486), Color(0xff087b5b)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RHM', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: .2)),
                    SizedBox(height: 2),
                    Text(_conversationTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Color(0xff7b8192), fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'مركز الإشعارات',
              onPressed: _api == null ? null : () => _openWorkspace('notifications'),
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
                          style: const TextStyle(
                            color: Colors.white,
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
        bottomNavigationBar: isWide
            ? const _AppVersionFooter()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RhmPrimaryNavigation(
                    selectedIndex: _selectedDestination,
                    onDestinationSelected: (index) => setState(() => _selectedDestination = index),
                  ),
                  const _AppVersionFooter(),
                ],
              ),
        body: Row(
          children: [
            if (isWide)
              RhmPrimaryNavigation(
                selectedIndex: _selectedDestination,
                useRail: true,
                onDestinationSelected: (index) => setState(() => _selectedDestination = index),
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
                                    ? const Color(0xff20a66a)
                                    : const Color(0xffc58b36),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _error ?? _status,
                            style: TextStyle(
                              color: _error == null ? const Color(0xff737b8e) : Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                  color: const Color(0xffe5f5ef),
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: const Icon(Icons.forum_rounded, size: 36, color: Color(0xff159b72)),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'أهلًا بك في RHM',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Color(0xff20263a)),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'أنا مساعدك الشخصي. اسألني، خطّط لمشاريعك، أو ابدأ محادثة صوتية.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, height: 1.7, color: Color(0xff777f92)),
                              ),
                              const SizedBox(height: 22),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _SuggestionChip(label: 'خطّط ليومي', icon: Icons.today_rounded, onTap: () => _useSuggestion('ساعدني في تنظيم يومي.')),
                                  _SuggestionChip(label: 'طوّر مشروعي', icon: Icons.code_rounded, onTap: () => _useSuggestion('ساعدني في تطوير مشروعي خطوة بخطوة.')),
                                  _SuggestionChip(label: 'تعلّم شيئًا', icon: Icons.school_rounded, onTap: () => _useSuggestion('اقترح لي درسًا عمليًا أتعلمه اليوم.')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final message = _messages[messageIndex];
                    final bubbleColor = message.isUser ? const Color(0xff159b72) : Colors.white;
                    final textColor = message.isUser ? Colors.white : const Color(0xff252b3b);
                    return Padding(
                      padding: EdgeInsets.only(
                        left: message.isUser ? 42 : 0,
                        right: message.isUser ? 0 : 42,
                        top: 5,
                        bottom: 7,
                      ),
                      child: Align(
                        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(message.isUser ? 20 : 6),
                                bottomRight: Radius.circular(message.isUser ? 6 : 20),
                              ),
                              boxShadow: message.isUser
                                  ? const []
                                  : [BoxShadow(color: const Color(0xff18264a).withValues(alpha: .045), blurRadius: 12, offset: const Offset(0, 3))],
                              border: message.isUser ? null : Border.all(color: const Color(0xffedf0f6)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(15, 12, 15, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Directionality(
                                    textDirection: _directionFor(message.text),
                                    child: message.isUser
                                        ? SelectableText(
                                            message.text,
                                            style: TextStyle(fontSize: 15, height: 1.55, color: textColor),
                                          )
                                        : MarkdownBody(
                                            data: message.text,
                                            selectable: true,
                                            styleSheet: MarkdownStyleSheet(
                                              a: TextStyle(color: Theme.of(context).colorScheme.primary),
                                              pPadding: EdgeInsets.zero,
                                              p: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xff252b3b)),
                                              h1: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xff20263a)),
                                              h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xff20263a)),
                                              h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xff20263a)),
                                              code: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xff175c47)),
                                              h1Padding: EdgeInsets.zero,
                                              h2Padding: EdgeInsets.zero,
                                              h3Padding: EdgeInsets.zero,
                                              h4: Theme.of(context).textTheme.bodyLarge,
                                              h5: Theme.of(context).textTheme.bodyLarge,
                                              h6: Theme.of(context).textTheme.bodyLarge,
                                              h4Padding: EdgeInsets.zero,
                                              h5Padding: EdgeInsets.zero,
                                              h6Padding: EdgeInsets.zero,
                                              em: const TextStyle(fontStyle: FontStyle.italic),
                                              strong: const TextStyle(fontWeight: FontWeight.bold),
                                              del: const TextStyle(decoration: TextDecoration.lineThrough),
                                              blockquote: Theme.of(context).textTheme.bodyMedium,
                                              img: Theme.of(context).textTheme.bodyMedium,
                                              checkbox: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                              blockSpacing: 8,
                                              listIndent: 24,
                                              listBullet: Theme.of(context).textTheme.bodyMedium,
                                              listBulletPadding: const EdgeInsets.only(right: 4),
                                              tableHead: const TextStyle(fontWeight: FontWeight.w600),
                                              tableBody: Theme.of(context).textTheme.bodyMedium,
                                              tableHeadAlign: TextAlign.center,
                                              tableBorder: buildRhmMarkdownTableBorder(Theme.of(context)),
                                              tablePadding: const EdgeInsets.only(bottom: 4),
                                              tableCellsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                              tableCellsDecoration: const BoxDecoration(),
                                              blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              blockquoteDecoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(3),
                                                border: Border(
                                                  left: BorderSide(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    width: 3,
                                                  ),
                                                ),
                                              ),
                                              codeblockPadding: const EdgeInsets.all(8),
                                              codeblockDecoration: BoxDecoration(
                                                color: Theme.of(context).cardTheme.color ??
                                                    Theme.of(context).colorScheme.surface,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                              horizontalRuleDecoration: BoxDecoration(
                                                border: Border(
                                                  top: BorderSide(
                                                    width: 1,
                                                    color: Theme.of(context).colorScheme.outlineVariant,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 7),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!message.isUser) ...[
                                        const Icon(Icons.auto_awesome, size: 13, color: Color(0xff329b78)),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            message.provider ?? 'RHM',
                                            style: const TextStyle(fontSize: 10, color: Color(0xff9299a9)),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'قراءة الرد',
                                          onPressed: () => _speakResponse(message.text),
                                          icon: const Icon(Icons.volume_up_rounded, size: 18, color: Color(0xff4c7e6b)),
                                        ),
                                      ],
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'نسخ الرسالة',
                                        onPressed: () => _copyMessage(message.text),
                                        icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xff7c8797)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedProjectName,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _projectScopeInitialized
                            ? 'سياق المشروع (مثبّت للمحادثة)'
                            : 'ربط المحادثة بمشروع',
                        prefixIcon: const Icon(Icons.folder_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('بدون مشروع محدد'),
                        ),
                        ..._projects.map(
                          (project) => DropdownMenuItem<String>(
                            value: project.name,
                            child: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (_projectScopeInitialized || _pendingRequestId != null)
                          ? null
                          : (value) => setState(() => _selectedProjectName = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _locale,
                            decoration: const InputDecoration(labelText: 'لغة الصوت'),
                            items: const [
                              DropdownMenuItem(value: 'ar-SA', child: Text('العربية')),
                              DropdownMenuItem(value: 'en-US', child: Text('English')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _locale = value);
                                _persistAppPreferences();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('تعرف محلي'),
                            value: _offlineRecognition,
                            onChanged: (value) {
                              setState(() => _offlineRecognition = value);
                              _persistAppPreferences();
                            },
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: const Color(0xffe8ebf3)),
                        boxShadow: [BoxShadow(color: const Color(0xff25345b).withValues(alpha: .05), blurRadius: 18, offset: const Offset(0, 5))],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: _listening ? 'إيقاف التسجيل' : 'تسجيل صوتي',
                            onPressed: _busy ? null : _toggleRecording,
                            style: IconButton.styleFrom(
                              backgroundColor: _listening ? const Color(0xffffe8e8) : const Color(0xffeef2ff),
                              foregroundColor: _listening ? const Color(0xffc73b45) : const Color(0xff159b72),
                            ),
                            icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_none_rounded),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _prompt,
                              minLines: 1,
                              maxLines: 5,
                              maxLength: 48000,
                              textDirection: _locale.startsWith('ar') ? TextDirection.rtl : TextDirection.ltr,
                              decoration: const InputDecoration(
                                hintText: 'اكتب رسالتك…',
                                counterText: '',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          IconButton.filled(
                            tooltip: 'إرسال الرسالة',
                            onPressed: _busy || _listening ? null : _sendMessage,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xff159b72),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xffb9c5e8),
                              minimumSize: const Size(46, 46),
                            ),
                            icon: _busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.arrow_upward_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'إيقاف القراءة الصوتية',
                          visualDensity: VisualDensity.compact,
                          onPressed: _speaking ? _stopSpeaking : null,
                          icon: const Icon(Icons.volume_off_outlined, size: 18, color: Color(0xff858da0)),
                        ),
                        const Flexible(
                          child: Text(
                            'قد تحتاج الردود إلى اتصال بخادم RHM.',
                            style: TextStyle(fontSize: 11, color: Color(0xff9299a9)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
                  ),
                  _api == null
                      ? _buildConnectionRequiredScreen('المشاريع')
                      : RhmProjectsScreen(api: _api!),
                  _buildActivityTab(),
                  _buildMoreTab(),
                  _selectedDestination == 4
                      ? (_api == null
                          ? _buildConnectionRequiredScreen('MCP')
                          : RhmMcpScreen(api: _api!))
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      );
  }
}

class _AppVersionFooter extends StatefulWidget {
  const _AppVersionFooter();

  @override
  State<_AppVersionFooter> createState() => _AppVersionFooterState();
}

class _AppVersionFooterState extends State<_AppVersionFooter> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xfff7f8fc),
            border: Border(top: BorderSide(color: Color(0xffe8ebf3))),
          ),
          child: FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = info == null
                  ? 'الإصدار …'
                  : 'الإصدار ${info.version}+${info.buildNumber}';
              return Text(
                'RHM  •  $version  •  © ${DateTime.now().year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xff9299a9),
                  letterSpacing: .2,
                ),
              );
            },
          ),
        ),
      );
}
