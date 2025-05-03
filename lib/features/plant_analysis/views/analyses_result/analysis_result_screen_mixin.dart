part of 'analysis_result_screen.dart';

mixin _AnalysisScreenResultMixin on State<AnalysisResultScreen> {
  PlantAnalysisResult? _analysisResult;
  bool _isLoading = true;
  String? _errorMessage;
  bool _initialLoadComplete = false;

  // Yazı boyutu seviyesi için state değişkeni
  int _fontSizeLevel = 0;

  // Animasyon kontrolcüsü
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Animasyon kontrolcüsünü başlat
    _animationController = AnimationController(
      vsync: this as TickerProvider,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    // Analiz ID'sini logla
    AppLogger.i(
      'AnalysisResultScreen açıldı - ID: ${widget.analysisId}, Uzunluk: ${widget.analysisId.length}',
    );

    // Analiz sonucunu yükle (sadece bir kez)
    _loadAnalysisResult();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Analiz sonucunu yükle ve yerel state'i güncelle
  Future<void> _loadAnalysisResult() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final cubit = context.read<PlantAnalysisCubit>();
      final completer = Completer<PlantAnalysisResult?>();

      final subscription = cubit.stream.listen((state) {
        if (!completer.isCompleted) {
          if (state.isLoading) {
            // Yükleme aşamasında bekle
            return;
          } else if (state.errorMessage != null) {
            // Hata durumunda tamamla
            completer.complete(null);
          } else if (state.selectedAnalysisResult != null) {
            // Sonuç hazır olduğunda tamamla
            completer.complete(state.selectedAnalysisResult);
          }
        }
      });

      // cubit metodunu çağır
      cubit.getAnalysisResult(widget.analysisId);

      // Sonucu bekle
      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          subscription.cancel();
          return null;
        },
      );

      subscription.cancel();

      if (result == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Analiz sonucu bulunamadı';
          _initialLoadComplete = true;
        });
        return;
      }

      setState(() {
        _analysisResult = result;
        _isLoading = false;
        _initialLoadComplete = true;
      });

      // Analiz sonucu yüklendiğinde animasyonu başlat
      _animationController.forward();

      AppLogger.i('Analiz sonucu başarıyla yüklendi - ID: ${result.id}');

      // Başarılı yükleme için hafif titreşim
      HapticFeedback.lightImpact();
    } catch (error) {
      AppLogger.e(
        'Analiz sonucu yüklenirken hata - ID: ${widget.analysisId}',
        error,
      );
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Analiz sonucu yüklenirken hata oluştu: ${error.toString()}';
        _initialLoadComplete = true;
      });
    }
  }
}
