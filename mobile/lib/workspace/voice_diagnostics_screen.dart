import 'package:material_ui/material_ui.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../rhm_theme.dart';
import '../workspace_shared.dart';

class RhmVoiceDiagnosticsScreen extends StatefulWidget {
  const RhmVoiceDiagnosticsScreen({
    super.key,
    required this.tts,
    required this.speech,
    required this.locale,
  });

  final FlutterTts tts;
  final SpeechToText speech;
  final String locale;

  @override
  State<RhmVoiceDiagnosticsScreen> createState() => _RhmVoiceDiagnosticsScreenState();
}

class _RhmVoiceDiagnosticsScreenState extends State<RhmVoiceDiagnosticsScreen> {
  @override
  void initState() {
    super.initState();
    _inspect();
  }

  bool _loading = true;
  bool _testing = false;
  bool _requestingPermission = false;
  bool _speechReady = false;
  bool _ttsLanguageAvailable = false;
  bool _ttsLanguageInstalled = false;
  String? _defaultEngine;
  List<String> _engines = [];
  List<Map<dynamic, dynamic>> _matchingVoices = [];
  List<LocaleName> _speechLocales = [];
  String? _error;
  String? _ttsError;
  String? _speechError;
  bool _speechPermissionGranted = false;
  String _status = 'جارٍ فحص خدمات الصوت على هذا الجهاز…';

  String get _language => widget.locale.split('-').first.toLowerCase();

  bool _isOffline(Map<dynamic, dynamic> voice) {
    final value = voice['network_required'];
    return value == false ||
        value == 0 ||
        value == '0' ||
        value == 'false';
  }

  String _normalizeLocale(String value) =>
      value.toLowerCase().replaceAll('_', '-');

  bool _matchesLocale(String value) {
    final normalized = _normalizeLocale(value);
    return normalized == _normalizeLocale(widget.locale) ||
        normalized == _language ||
        normalized.startsWith('$_language-');
  }

  Future<void> _inspect() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _ttsError = null;
      _speechError = null;
      _status = 'جارٍ فحص محركات النطق والتعرف…';
    });

    var engines = <String>[];
    String? defaultEngine;
    var voices = <Map<dynamic, dynamic>>[];
    var ttsLanguageAvailable = false;
    var ttsLanguageInstalled = false;
    String? ttsError;

    // TTS diagnostics must remain useful even when speech recognition is
    // missing, denied, or temporarily unavailable on the Android device.
    try {
      final dynamic rawEngines = await widget.tts.getEngines;
      final dynamic rawDefaultEngine = await widget.tts.getDefaultEngine;
      final dynamic rawVoices = await widget.tts.getVoices;
      final dynamic available = await widget.tts.isLanguageAvailable(widget.locale);
      final dynamic installed = await widget.tts.isLanguageInstalled(widget.locale);

      engines = (rawEngines as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList();
      defaultEngine = rawDefaultEngine?.toString();
      voices = (rawVoices as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .where((voice) => voice['locale'] is String)
          .where((voice) => _matchesLocale(voice['locale'] as String))
          .toList()
        ..sort((left, right) {
          final leftOffline = _isOffline(left) ? 0 : 1;
          final rightOffline = _isOffline(right) ? 0 : 1;
          final offlineOrder = leftOffline.compareTo(rightOffline);
          if (offlineOrder != 0) return offlineOrder;
          final leftExact = _normalizeLocale(left['locale'].toString()) ==
                  _normalizeLocale(widget.locale)
              ? 0
              : 1;
          final rightExact = _normalizeLocale(right['locale'].toString()) ==
                  _normalizeLocale(widget.locale)
              ? 0
              : 1;
          return leftExact.compareTo(rightExact);
        });
      ttsLanguageAvailable = available == true;
      ttsLanguageInstalled = installed == true;
    } catch (_) {
      ttsError = 'تعذر قراءة معلومات محرك النطق. تحقق من محرك تحويل النص إلى كلام في إعدادات Android.';
    }

    var speechPermissionGranted = false;
    var speechReady = false;
    var speechLocales = <LocaleName>[];
    String? speechError;

    // Query speech locales only after initialization, and never request a
    // microphone permission simply because the diagnostics page was opened.
    try {
      speechPermissionGranted = await widget.speech.hasPermission;
      if (!speechPermissionGranted) {
        speechError = 'إذن الميكروفون غير ممنوح. اضغط زر طلب الإذن لفحص خدمة التعرف.';
      } else {
        speechReady = await widget.speech.initialize(
          onError: (error) {
            if (mounted) {
              setState(() {
                _speechReady = false;
                _speechError = 'خدمة التعرف أبلغت عن خطأ: ${error.errorMsg}';
              });
            }
          },
          onStatus: (_) {},
        );
        if (speechReady) {
          final locales = await widget.speech.locales();
          speechLocales = locales
              .where((item) => _matchesLocale(item.localeId))
              .toList()
            ..sort((left, right) {
              final leftExact = _normalizeLocale(left.localeId) ==
                      _normalizeLocale(widget.locale)
                  ? 0
                  : 1;
              final rightExact = _normalizeLocale(right.localeId) ==
                      _normalizeLocale(widget.locale)
                  ? 0
                  : 1;
              return leftExact.compareTo(rightExact);
            });
          if (speechLocales.isEmpty) {
            speechError = 'خدمة التعرف جاهزة، لكنها لم تُرجع لغة مطابقة. تحقق من حزم اللغات في Android.';
          }
        } else {
          speechError = 'تعذر تهيئة خدمة التعرف رغم منح إذن الميكروفون. تحقق من تثبيت خدمة كلام متوافقة.';
        }
      }
    } catch (_) {
      speechError = 'تعذر فحص خدمة التعرف. تحقق من إذن الميكروفون وخدمة الكلام المثبتة في Android.';
    }

    if (!mounted) return;
    setState(() {
      _engines = engines;
      _defaultEngine = defaultEngine;
      _matchingVoices = voices;
      _speechLocales = speechLocales;
      _ttsLanguageAvailable = ttsLanguageAvailable;
      _ttsLanguageInstalled = ttsLanguageInstalled;
      _speechPermissionGranted = speechPermissionGranted;
      _speechReady = speechReady;
      _ttsError = ttsError;
      _speechError = speechError;
      _status = 'اكتمل فحص خدمات الصوت المتاحة. يمكنك اختبار النطق وطلب إذن الميكروفون بصورة مستقلة.';
    });
  }

  Future<void> _requestSpeechPermission() async {
    if (_requestingPermission) return;
    setState(() {
      _requestingPermission = true;
      _speechError = null;
      _status = 'جارٍ طلب إذن الميكروفون وتهيئة خدمة التعرف…';
    });
    try {
      final ready = await widget.speech.initialize(
        onError: (error) {
          if (mounted) {
            setState(() {
              _speechReady = false;
              _speechError = 'خدمة التعرف أبلغت عن خطأ: ${error.errorMsg}';
            });
          }
        },
        onStatus: (status) {
          if (mounted) setState(() => _status = 'حالة خدمة التعرف: $status');
        },
      );
      final permissionGranted = await widget.speech.hasPermission;
      final locales = ready ? await widget.speech.locales() : <LocaleName>[];
      if (!mounted) return;
      final matchingLocales = locales
          .where((item) => _matchesLocale(item.localeId))
          .toList()
        ..sort((left, right) {
          final leftExact = _normalizeLocale(left.localeId) ==
                  _normalizeLocale(widget.locale)
              ? 0
              : 1;
          final rightExact = _normalizeLocale(right.localeId) ==
                  _normalizeLocale(widget.locale)
              ? 0
              : 1;
          return leftExact.compareTo(rightExact);
        });
      setState(() {
        _speechPermissionGranted = permissionGranted;
        _speechReady = ready;
        _speechLocales = matchingLocales;
        _speechError = !permissionGranted
            ? 'لم يمنح Android إذن الميكروفون. راجع أذونات التطبيق.'
            : !ready
                ? 'لم تصبح خدمة التعرف جاهزة. راجع خدمة الكلام المثبتة في Android.'
                : matchingLocales.isEmpty
                    ? 'خدمة التعرف جاهزة، لكن لا توجد لغة مطابقة للغة المختارة.'
                    : null;
        _status = _speechError == null
            ? 'خدمة التعرف جاهزة. اللغات المطابقة: ${matchingLocales.length}.'
            : 'لم يكتمل إعداد التعرف على الكلام.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _speechPermissionGranted = false;
          _speechReady = false;
          _speechError = 'فشلت تهيئة خدمة التعرف. تأكد من منح إذن الميكروفون وتثبيت خدمة كلام متوافقة.';
          _status = 'تعذر إعداد التعرف على الكلام.';
        });
      }
    } finally {
      if (mounted) setState(() => _requestingPermission = false);
    }
  }

  Future<void> _testSpeechOutput() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _error = null;
      _status = 'جارٍ تشغيل عينة صوتية للغة ${widget.locale}…';
    });
    try {
      final offlineVoices = _matchingVoices.where(_isOffline).toList();
      final selected = offlineVoices.isNotEmpty
          ? offlineVoices.first
          : (_matchingVoices.isNotEmpty ? _matchingVoices.first : null);
      if (selected != null) {
        await widget.tts.setVoice({
          'name': selected['name'].toString(),
          'locale': selected['locale'].toString(),
        });
      } else {
        final available = await widget.tts.isLanguageAvailable(widget.locale);
        if (available != true) {
          throw StateError('No voice is available for ${widget.locale}.');
        }
        await widget.tts.setLanguage(widget.locale);
      }
      await widget.tts.setSpeechRate(0.48);
      await widget.tts.setVolume(1);
      await widget.tts.setPitch(1);
      await widget.tts.awaitSpeakCompletion(true);
      final result = await widget.tts.speak(
        widget.locale.toLowerCase().startsWith('ar')
            ? 'مرحبًا، هذا اختبار لصوت مساعد RHM. إذا سمعت هذه الجملة بوضوح، فمحرك النطق يعمل.'
            : 'Hello. This is a test of the RHM assistant voice. If you can hear this sentence clearly, speech output is working.',
        focus: true,
      );
      if (!mounted) return;
      setState(() {
        _status = result == 1
            ? (selected != null && _isOffline(selected)
                ? 'نجح الاختبار باستخدام صوت محلي مثبت.'
                : 'بدأ الاختبار باستخدام محرك الصوت المتاح؛ قد يتطلب اتصالًا.')
            : 'لم يبدأ محرك النطق القراءة. تحقق من إعدادات تحويل النص إلى كلام في Android.';
        if (result != 1) _error = 'لم يقبل محرك النطق طلب القراءة.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'فشل اختبار النطق. قد تكون حزمة اللغة غير مثبتة أو قد لا يدعم المحرك اللغة المحددة.';
          _status = 'تعذر تشغيل عينة الصوت.';
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _stopSpeechOutput() async {
    await widget.tts.stop();
    if (mounted) setState(() => _status = 'تم إيقاف القراءة الصوتية.');
  }

  @override
  Widget build(BuildContext context) {
    final offlineCount = _matchingVoices.where(_isOffline).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تشخيص الصوت'),
        actions: [
          IconButton(
            tooltip: 'إعادة الفحص',
            onPressed: _loading ? null : _inspect,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? workspaceLoadingWidget()
          : RefreshIndicator(
              onRefresh: _inspect,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                children: [
                  Card(
                    elevation: 0,
                    color: Theme.of(context).extension<RhmUiTokens>()!.accentSoft,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(_status, style: const TextStyle(height: 1.5)),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (_ttsError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _ttsError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _diagnosticCard(
                    title: 'محرك تحويل النص إلى كلام',
                    icon: Icons.record_voice_over_outlined,
                    children: [
                      _diagnosticLine('المحرك الافتراضي', _defaultEngine ?? 'غير متاح'),
                      _diagnosticLine('محركات مثبتة', '${_engines.length}'),
                      ..._engines.map((engine) => _diagnosticLine('محرك', engine)),
                      _diagnosticLine(
                        'دعم اللغة ${widget.locale}',
                        _ttsLanguageAvailable ? 'متاحة للمحرك' : 'غير متاحة للمحرك',
                      ),
                      _diagnosticLine(
                        'حزمة اللغة المحلية',
                        _ttsLanguageInstalled ? 'مثبتة' : 'غير مؤكدة/غير مثبتة',
                      ),
                      _diagnosticLine('أصوات مطابقة', '${_matchingVoices.length}'),
                      _diagnosticLine('أصوات محلية', '$offlineCount'),
                      const SizedBox(height: 8),
                      if (_matchingVoices.isEmpty)
                        const Text(
                          'لا توجد أصوات مطابقة للغة المختارة. افتح إعدادات تحويل النص إلى كلام في Android وثبّت صوتًا عربيًا أو إنجليزيًا.',
                          style: TextStyle(height: 1.5),
                        )
                      else
                        ..._matchingVoices.map((voice) {
                          final locale = voice['locale']?.toString() ?? '';
                          final name = voice['name']?.toString() ?? 'صوت بلا اسم';
                          return _diagnosticLine(
                            name,
                            '$locale · ${_isOffline(voice) ? 'محلي' : 'قد يحتاج الإنترنت'}',
                          );
                        }),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _testing ? null : _testSpeechOutput,
                            icon: const Icon(Icons.play_arrow),
                            label: Text(_testing ? 'جارٍ التشغيل…' : 'اختبار القراءة'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _stopSpeechOutput,
                            icon: const Icon(Icons.stop),
                            label: const Text('إيقاف'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _diagnosticCard(
                    title: 'التعرف على الكلام والميكروفون',
                    icon: Icons.mic_none_rounded,
                    children: [
                      if (_speechError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _speechError!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error, height: 1.45),
                          ),
                        ),
                      _diagnosticLine(
                        'إذن الميكروفون',
                        _speechPermissionGranted ? 'ممنوح' : 'غير ممنوح',
                      ),
                      _diagnosticLine(
                        'خدمة التعرف',
                        _speechReady ? 'متاحة' : 'غير مهيأة',
                      ),
                      _diagnosticLine(
                        'لغة ${widget.locale}',
                        '${_speechLocales.length} لغة/منطقة مطابقة',
                      ),
                      if (_speechLocales.isEmpty)
                        const Text(
                          'لم تُرجع خدمة التعرف لغة مطابقة. ثبّت خدمة كلام مثل Google Speech Services وحزمة اللغة في إعدادات Android.',
                          style: TextStyle(height: 1.5),
                        )
                      else
                        ..._speechLocales.map(
                          (locale) => _diagnosticLine(locale.name, locale.localeId),
                        ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _requestingPermission ? null : _requestSpeechPermission,
                        icon: _requestingPermission
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.mic),
                        label: Text(
                          _requestingPermission
                              ? 'جارٍ التحقق…'
                              : 'طلب إذن الميكروفون وفحص التعرف',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ملاحظة: تطبيق RHM يستخدم محركات Android المثبتة ولا يضمّن أصواتًا أو نموذج تعرف صوتي داخل APK. عدم توفر صوت محلي لا يعني بالضرورة تعذر استخدام صوت متصل بالشبكة.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _diagnosticCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) =>
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: BorderSide(color: Theme.of(context).extension<RhmUiTokens>()!.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 22),
              ...children,
            ],
          ),
        ),
      );

  Widget _diagnosticLine(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
