part of 'chat_screen.dart';

extension _ChatScreenVoice on _ChatScreenState {
  Future<void> _toggleRecording() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) {
        this._setState(() {
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
              this._setState(() {
                _listening = false;
                _error = _offlineRecognition
                    ? 'تعذر التعرف المحلي أو لم يُسمح بإذن الميكروفون.'
                    : 'تعذر التعرف على الكلام. تحقق من إذن الميكروفون وخدمات الصوت.';
              });
            }
          },
          onStatus: (status) {
            if (status == 'notListening' && mounted) {
              this._setState(() => _listening = false);
            }
          },
        );
      }
      if (!mounted) return;
      if (!_speechInitialized) {
        this._setState(() => _error = 'التعرف على الكلام غير متاح أو لم يُسمح بإذن الميكروفون.');
        return;
      }
      matchingLocales = await _speech.locales();
    } catch (_) {
      if (mounted) {
        this._setState(() => _error = 'تعذر تهيئة خدمة التعرف أو قراءة اللغات المتاحة.');
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
      this._setState(() => _error = 'لغة $_locale غير متاحة في خدمة التعرف على هذا الجهاز.');
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
      this._setState(() {
        _listening = true;
        _error = null;
        _status = _offlineRecognition
            ? 'يحاول الجهاز التعرف محليًا؛ لن يتحول تلقائيًا إلى التعرف عبر الإنترنت.'
            : 'التعرف عبر خدمة الجهاز؛ قد يتطلب اتصالًا بحسب إعدادات Android.';
      });
    } catch (_) {
      this._setState(() {
        _listening = false;
        _error = _offlineRecognition
            ? 'التعرف المحلي غير متاح. ثبّت حزمة اللغة على الجهاز أو اختر التعرف عبر الإنترنت.'
            : 'تعذر بدء التسجيل. تحقق من إذن الميكروفون.';
      });
    }
  }

  void _useSuggestion(String value) {
    this._setState(() {
      _prompt.text = value;
      _prompt.selection = TextSelection.collapsed(offset: value.length);
    });
    _scheduleComposerDraftSave(value);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final recognized = result.recognizedWords.trim();
    final combined = [_voiceBase, recognized].where((part) => part.isNotEmpty).join(' ');
    _prompt.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );
    _scheduleComposerDraftSave(combined);
    if (result.finalResult && mounted) {
      this._setState(() {
        _listening = false;
        _status = 'راجع النص وعدّله قبل إرساله.';
      });
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
      this._setState(() {
        _error = null;
        _status = usingOfflineVoice
            ? 'تتم قراءة الرد بصوت محلي مثبت على الجهاز.'
            : 'تتم قراءة الرد عبر محرك الصوت المتاح؛ قد يحتاج هذا الصوت إلى الإنترنت.';
      });
      final result = await _tts.speak(text, focus: true);
      if (result != 1 && mounted) {
        this._setState(() {
          _speaking = false;
          _error = 'لم يبدأ محرك الصوت القراءة. تحقق من إعدادات تحويل النص إلى كلام في Android.';
        });
      }
    } catch (_) {
      if (mounted) {
        this._setState(() {
          _speaking = false;
          _error = 'لا يتوفر صوت مناسب للغة المختارة. ثبّت صوتًا عربيًا/إنجليزيًا من إعدادات Android أو غيّر محرك تحويل النص إلى كلام.';
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    if (mounted) this._setState(() => _speaking = false);
  }
}
