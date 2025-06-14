part of 'analysis_result_screen.dart';

mixin _AnalysisScreenResultMixin on State<AnalysisResultScreen> {
  PlantAnalysisResult? _analysisResult;
  bool _isLoading = true;
  String? _errorMessage;

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
          } else if (state.currentAnalysis != null) {
            // Sonuç hazır olduğunda tamamla - conversion ile
            completer.complete(
                _convertToPlantAnalysisResult(state.currentAnalysis!));
          }
        }
      });

      // cubit metodunu çağır
      cubit.loadAnalysisById(widget.analysisId);

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
        });
        return;
      }

      setState(() {
        _analysisResult = result;
        _isLoading = false;
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
      });
    }
  }

  /// Converts PlantAnalysisEntity to PlantAnalysisResult
  ///
  /// Entity'den Result model'ine çeviri yapar UI widget'ları için.
  /// Clean Architecture prensiplerine uygun şekilde katmanlar arası conversion.
  PlantAnalysisResult _convertToPlantAnalysisResult(
      PlantAnalysisEntity entity) {
    return PlantAnalysisResult(
      id: entity.id,
      plantName: entity.plantName,
      probability: entity.probability,
      isHealthy: entity.isHealthy,
      diseases:
          entity.diseases.map((disease) => _convertDisease(disease)).toList(),
      description: entity.description,
      suggestions: entity.suggestions,
      imageUrl: entity.imageUrl,
      similarImages: entity.similarImages,
      location: entity.location,
      fieldName: entity.fieldName,
      timestamp: entity.timestamp?.millisecondsSinceEpoch,
      // Optional fields with defaults for UI layer
      taxonomy: null,
      edibleParts: null,
      propagationMethods: null,
      watering: null,
      sunlight: null,
      soil: null,
      climate: null,
      geminiAnalysis: null,
      growthStage: null,
      growthScore: null,
      growthComment: null,
      interventionMethods: null,
      agriculturalTips: null,
      regionalInfo: null,
      rawResponse: null,
    );
  }

  /// Converts entity Disease to result Disease
  ///
  /// Domain entity Disease'den data model Disease'e conversion.
  /// Eksik alanlar null olarak atanır.
  Disease _convertDisease(entity_disease.Disease entityDisease) {
    return Disease(
      name: entityDisease.name,
      probability: entityDisease.probability,
      description: entityDisease.description,
      treatments: entityDisease.treatments,
      severity: entityDisease.severity.value,
      symptoms: null,
      interventionMethods: null,
      pesticideSuggestions: null,
      affectedParts: null,
      causalAgent: null,
      preventiveMeasures: null,
      imageUrls: null,
      similarDiseases: null,
    );
  }
}
