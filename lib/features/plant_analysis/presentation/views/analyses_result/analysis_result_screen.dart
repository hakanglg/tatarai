import 'dart:async';
import 'dart:convert'; // Base64 için eklendi
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart'; // AppDimensions için import eklendi
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';

import 'package:tatarai/features/plant_analysis/data/models/plant_analysis_model.dart';
import 'package:tatarai/features/plant_analysis/domain/entities/plant_analysis_entity.dart';
import 'package:tatarai/features/plant_analysis/data/models/disease_model.dart';
import 'package:tatarai/features/plant_analysis/presentation/cubits/plant_analysis_state.dart';
import 'package:tatarai/features/plant_analysis/presentation/views/widgets/font_size_control.dart';
import 'package:tatarai/features/plant_analysis/presentation/views/widgets/info_card_item.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/services/service_locator.dart';
import 'package:tatarai/core/repositories/plant_analysis_repository.dart';

part 'analysis_result_screen_mixin.dart';

/// PlantAnalysisModel için UI gösterimine yardımcı uzantılar
extension PlantAnalysisModelUIExtension on PlantAnalysisModel {
  /// Sağlık durumuna göre renk döndürür
  Color getHealthStatusColor() {
    return isHealthy ? AppColors.primary : AppColors.error;
  }

  /// Sağlık durumu başlığını döndürür
  String getHealthStatusTitle() {
    return isHealthy ? 'Bitkiniz Sağlıklı' : 'Sağlık Sorunu Tespit Edildi';
  }

  /// Sağlık durumu açıklamasını döndürür
  String getHealthStatusDescription() {
    return isHealthy
        ? 'Bitkiniz iyi durumda görünüyor'
        : 'Bitkinizde bazı sorunlar tespit edildi';
  }

  /// Gelişim skoruna göre renk döndürür
  Color getGrowthScoreColor(int score) {
    if (score >= 80) return CupertinoColors.systemGreen;
    if (score >= 60) return AppColors.info;
    if (score >= 40) return CupertinoColors.systemYellow;
    if (score >= 20) return CupertinoColors.systemOrange;
    return CupertinoColors.systemRed;
  }

  /// Gelişim skoruna göre açıklama metni döndürür
  String getGrowthScoreText(int score) {
    if (score >= 80) {
      return 'Bitkinin gelişimi mükemmel, ideal koşullarda büyüyor.';
    }
    if (score >= 60) {
      return 'Bitkinin gelişimi iyi durumda, büyüme devam ediyor.';
    }
    if (score >= 40) {
      return 'Ortalama bir gelişim gösteriyor, bakım koşulları iyileştirilebilir.';
    }
    if (score >= 20) {
      return 'Gelişim yavaş, acil bakım ve müdahale gerekebilir.';
    }
    return 'Kritik gelişim seviyesi, acil müdahale gerekiyor.';
  }

  /// Gelişim durumuna göre tavsiye metni döndürür
  String getGrowthAdvice(int score, String? stage) {
    final String stageText = stage?.toLowerCase() ?? '';

    if (score >= 80) {
      if (stageText.contains('çiçek') || stageText.contains('cicek')) {
        return 'Çiçeklenme döneminde gübre desteğini sürdürün, düzenli sulama çok önemli.';
      } else if (stageText.contains('fide') || stageText.contains('fidan')) {
        return 'Fide aşamasında iyi gelişiyor, düzenli sulamaya devam edin.';
      } else if (stageText.contains('meyve')) {
        return 'Meyvelenme döneminde potasyum açısından zengin gübreler tercih edin.';
      } else if (stageText.contains('olgun')) {
        return 'Olgunlaşma sürecinde ideal koşullar sağlanmış, aynı şekilde devam edin.';
      }
      return 'Şu anki bakım koşullarını koruyun, bitkiniz çok iyi gelişiyor.';
    } else if (score >= 60) {
      if (stageText.contains('çiçek') || stageText.contains('cicek')) {
        return 'Çiçeklenme döneminde daha fazla fosfor içerikli gübre kullanın.';
      } else if (stageText.contains('fide') || stageText.contains('fidan')) {
        return 'Fide aşamasında daha dengeli bir sulama programı uygulayın.';
      } else if (stageText.contains('meyve')) {
        return 'Meyvelenme için ek mikro element takviyesi yapmanız faydalı olabilir.';
      } else if (stageText.contains('olgun')) {
        return 'Olgunlaşma sürecinde ışık koşullarını optimize edin.';
      }
      return 'Biraz daha gübreleme ve optimize edilmiş sulama ile gelişimi artırabilirsiniz.';
    } else if (score >= 40) {
      if (stageText.contains('çiçek') || stageText.contains('cicek')) {
        return 'Çiçeklenme için acilen fosfor/potasyum dengesini sağlayın.';
      } else if (stageText.contains('fide') || stageText.contains('fidan')) {
        return 'Fide gelişimi yavaş, daha fazla ışık ve dengeli gübreleme gerekli.';
      } else if (stageText.contains('meyve')) {
        return 'Meyvelenme durdurmak üzere, acilen toprak analizi yaptırın.';
      } else if (stageText.contains('olgun')) {
        return 'Olgunlaşma gecikiyor, su ve besin eksikliği olabilir.';
      }
      return 'Bakım koşullarında önemli iyileştirmeler gerekiyor. Toprak, ışık ve sulama programını gözden geçirin.';
    } else {
      return 'Acil müdahale gerektiren bir gelişim durumu görülüyor. Toprak değişimi, gübre takviyesi ve sulama düzeninde değişiklik düşünülmeli.';
    }
  }

  /// Hastalık şiddet seviyesini döndürür (Yüksek, Orta, Düşük)
  String getDiseaseServerityText(Disease disease) {
    return (disease.probability ?? 0.0) >= 0.7
        ? 'Yüksek'
        : (disease.probability ?? 0.0) >= 0.4
            ? 'Orta'
            : 'Düşük';
  }

  /// Hastalık şiddet seviyesine göre renk döndürür
  Color getDiseaseServerityColor(Disease disease) {
    return (disease.probability ?? 0.0) >= 0.7
        ? CupertinoColors.systemRed
        : (disease.probability ?? 0.0) >= 0.4
            ? CupertinoColors.systemYellow
            : CupertinoColors.systemGreen;
  }
}

/// Analiz sonuçları ekranı
/// Yapay zeka tarafından yapılan bitki analiz sonuçlarını gösterir
class AnalysisResultScreen extends StatefulWidget {
  /// Default constructor
  const AnalysisResultScreen({
    super.key,
    required this.analysisId,
    this.analysisResult,
  });

  /// Analiz ID'si
  final String analysisId;

  /// Opsiyonel analiz sonucu (doğrudan veri geçmek için)
  final PlantAnalysisModel? analysisResult;

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen>
    with SingleTickerProviderStateMixin, AnalysisResultScreenMixin {
  // Analiz sonucunu local olarak tutmak için - AnalysisResultScreenMixin'den geliyor

  // UI state değişkenleri
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Font size kontrolü
  int _fontSizeLevel = 0;
  double _currentFontSize = AppTextTheme.bodyText2.fontSize ?? 14.0;

  /// Analiz sonucunu tutacak değişken
  PlantAnalysisModel? _currentAnalysisResult;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _currentAnalysisResult = widget.analysisResult;
    _loadAnalysisResult();
  }

  @override
  void dispose() {
    _animationController.dispose();
    cleanupMixin(); // Mixin'in cleanup metodunu çağır
    super.dispose();
  }

  /// Analiz sonucunu yükler
  Future<void> _loadAnalysisResult() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Eğer widget oluşturulurken analiz sonucu verilmişse, onu kullan
      if (widget.analysisResult != null) {
        // Eğer analiz sonucu bozuk/eksikse (Analiz Edilemedi), repository'den tekrar çek
        if (widget.analysisResult!.plantName == 'Analiz edilemedi' ||
            widget.analysisResult!.plantName == 'Analiz Edilemedi') {
          AppLogger.w(
              '⚠️ Başarısız analiz tespit edildi, repository\'den kontrol ediliyor...');
          // Repository'den tekrar çek - fall through
        } else {
          _currentAnalysisResult = widget.analysisResult;
          setAnalysisResult(widget.analysisResult);
          setState(() {
            _isLoading = false;
          });
          _animationController.forward();
          logAnalysisResult();
          return;
        }
      }

      // Repository'den analiz sonucunu yükle
      final repository = ServiceLocator.get<PlantAnalysisRepository>();
      final analysisEntity =
          await repository.getAnalysisResult(widget.analysisId);

      if (analysisEntity != null) {
        // Entity'den model'e dönüştür (mixin method'unu kullan)
        final convertedModel = _convertToPlantAnalysisModel(analysisEntity);

        // Eğer repository'den de başarısız analiz geldiyse, kullanıcıyı bilgilendir
        if (convertedModel.plantName == 'Analiz Edilemedi') {
          AppLogger.w(
              '⚠️ Repository\'den de başarısız analiz geldi, ana ekrana yönlendiriliyor');
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: SelectableText(
                    'Bu analiz başarısız olmuş. Lütfen yeni bir analiz yapın.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        _currentAnalysisResult = convertedModel;
        setAnalysisResult(convertedModel);

        setState(() {
          _isLoading = false;
        });

        _animationController.forward();
        logAnalysisResult();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Belirtilen ID ile analiz sonucu bulunamadı';
        });
      }
    } catch (e, stackTrace) {
      AppLogger.e('Analiz sonucu yükleme hatası', e, stackTrace);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Analiz yüklenemedi: ${e.toString()}';
      });
    }
  }

  //#####
  // _buildInfoRow metodu, genel bilgi satırlarını oluşturmak için kullanılır.
  // Simge, etiket, değer ve değer rengini parametre olarak alır.
  // Bu metot, _AnalysisResultScreenState sınıfının bir parçasıdır.
  //#####

  // Fonksiyon _fontSizeLevel'a göre dinamik olarak fontSize döndürür.
  // Bu, uygulamanızın genel text ölçeklendirme mantığına göre ayarlanabilir.
  double _calculateFontSize(int level) {
    final baseSize = AppTextTheme.bodyText2.fontSize ?? 14.0;
    return baseSize + (level * 1.0);
  }

  //#####
  // _buildHealthInfo metodu, _AnalysisResultScreenState sınıfının bir üyesi haline getirildi.
  // İlaç önerileri bölümü de bu metoda entegre edilmiştir.
  //#####

  /// Gelişim skoru widget'ı oluşturur - Modern Apple design
  Widget _buildGrowthScoreWidget(PlantAnalysisModel result) {
    final score = result.growthScore ?? 0;
    final color = result.getGrowthScoreColor(score);
    final dim = context.dimensions;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CupertinoColors.systemBackground,
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern gelişim skoru başlığı ve circular progress
          Row(
            children: [
              // Circular progress indicator
              Container(
                width: 64,
                height: 64,
                child: Stack(
                  children: [
                    // Background circle
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.1),
                      ),
                    ),
                    // Progress circle
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 6,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        backgroundColor: color.withOpacity(0.2),
                      ),
                    ),
                    // Score text in center
                    Center(
                      child: SelectableText(
                        '$score',
                        style: AppTextTheme.headline6.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        toolbarOptions: const ToolbarOptions(
                          copy: true,
                          selectAll: true,
                          cut: false,
                          paste: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: dim.spaceL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      'Gelişim Skoru',
                      style: AppTextTheme.headline6.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      toolbarOptions: const ToolbarOptions(
                        copy: true,
                        selectAll: true,
                        cut: false,
                        paste: false,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.15),
                            color.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: SelectableText(
                        '${score}/100 Puan',
                        style: AppTextTheme.captionL.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                        toolbarOptions: const ToolbarOptions(
                          copy: true,
                          selectAll: true,
                          cut: false,
                          paste: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Gelişim aşaması göster (varsa) - VURGULU
          if (result.growthStage != null && result.growthStage!.isNotEmpty) ...[
            SizedBox(height: dim.spaceM),
            Container(
              padding: EdgeInsets.all(dim.paddingM),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.15),
                    color.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(dim.radiusM),
                border: Border.all(
                  color: color.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(dim.paddingS),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.clock_fill,
                      color: color,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: dim.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          'Gelişim Aşaması',
                          style: AppTextTheme.captionL.copyWith(
                            color: color.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                            fontSize: _currentFontSize * 0.85,
                          ),
                          toolbarOptions: const ToolbarOptions(
                            copy: true,
                            selectAll: true,
                            cut: false,
                            paste: false,
                          ),
                        ),
                        SizedBox(height: dim.spaceXS),
                        SelectableText(
                          result.growthStage!,
                          style: AppTextTheme.bodyText1.copyWith(
                            color: color,
                            fontSize: _currentFontSize * 1.05,
                            fontWeight: FontWeight.bold,
                          ),
                          toolbarOptions: const ToolbarOptions(
                            copy: true,
                            selectAll: true,
                            cut: false,
                            paste: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: dim.spaceS),

          // Progress bar
          Container(
            height: AppConstants.progressBarHeight,
            decoration: BoxDecoration(
              color: color.withOpacity(AppConstants.opacityLight * 2),
              borderRadius:
                  BorderRadius.circular(AppConstants.progressBarRadius),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: score / AppConstants.maxGrowthScore,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius:
                      BorderRadius.circular(AppConstants.progressBarRadius),
                ),
              ),
            ),
          ),
          SizedBox(height: dim.spaceS),

          // Genel durum açıklaması
          SelectableText(
            result.getGrowthScoreText(score),
            style: AppTextTheme.bodyText2.copyWith(
              color: AppColors.textSecondary,
              fontSize: _currentFontSize,
            ),
            toolbarOptions: const ToolbarOptions(
              copy: true,
              selectAll: true,
              cut: false,
              paste: false,
            ),
          ),

          // Detaylı gelişim yorumu (varsa)
          if (result.growthComment != null &&
              result.growthComment!.isNotEmpty) ...[
            SizedBox(height: dim.spaceM),
            Container(
              padding: EdgeInsets.all(dim.paddingS),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(dim.radiusS),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.text_bubble_fill,
                        color: color.withOpacity(0.7),
                        size: 16,
                      ),
                      SizedBox(width: dim.spaceXS),
                      SelectableText(
                        'Gelişim Hakkında',
                        style: AppTextTheme.captionL.copyWith(
                          color: color.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                        ),
                        toolbarOptions: const ToolbarOptions(
                          copy: true,
                          selectAll: true,
                          cut: false,
                          paste: false,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: dim.spaceXS),
                  SelectableText(
                    result.growthComment!,
                    style: AppTextTheme.bodyText2.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: _currentFontSize * 0.95,
                      height: 1.4,
                    ),
                    toolbarOptions: const ToolbarOptions(
                      copy: true,
                      selectAll: true,
                      cut: false,
                      paste: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Hastalık detayları için genişletilmiş widget
  Widget _buildExpandedDiseaseInfo(Disease disease) {
    final dim = context.dimensions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hastalık açıklaması (varsa)
        if (disease.description != null && disease.description!.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(dim.paddingM),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(dim.radiusM),
              border: Border.all(
                color: CupertinoColors.systemBlue.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.info_circle_fill,
                      color: CupertinoColors.systemBlue,
                      size: 18,
                    ),
                    SizedBox(width: dim.spaceS),
                    SelectableText(
                      'Hastalık Detayları',
                      style: AppTextTheme.bodyText1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemBlue,
                      ),
                      toolbarOptions: const ToolbarOptions(
                        copy: true,
                        selectAll: true,
                        cut: false,
                        paste: false,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: dim.spaceS),
                SelectableText(
                  disease.description!,
                  style: AppTextTheme.bodyText2.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: _currentFontSize,
                    height: 1.4,
                  ),
                  toolbarOptions: const ToolbarOptions(
                    copy: true,
                    selectAll: true,
                    cut: false,
                    paste: false,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: dim.spaceM),
        ],

        // Tedavi önerileri
        if (disease.treatments.isNotEmpty) ...[
          _buildTreatmentSection('Tedavi Önerileri', disease.treatments),
          SizedBox(height: dim.spaceM),

          // İlaç önerileri (aynı treatments listesini farklı başlıkla göster)
          _buildTreatmentSection('İlaç Önerileri', disease.treatments),
        ] else ...[
          // Tedavi bilgisi yoksa bilgilendirme mesajı
          Container(
            padding: EdgeInsets.all(dim.paddingM),
            decoration: BoxDecoration(
              color: CupertinoColors.systemYellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(dim.radiusM),
              border: Border.all(
                color: CupertinoColors.systemYellow.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: CupertinoColors.systemYellow,
                  size: 20,
                ),
                SizedBox(width: dim.spaceS),
                Expanded(
                  child: SelectableText(
                    'Bu hastalık için detaylı tedavi bilgisi henüz mevcut değil. Genel bitki bakım kurallarına uyarak bitkinizin sağlığını koruyabilirsiniz.',
                    style: AppTextTheme.bodyText2.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: _currentFontSize * 0.95,
                      height: 1.3,
                    ),
                    toolbarOptions: const ToolbarOptions(
                      copy: true,
                      selectAll: true,
                      cut: false,
                      paste: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Tedavi bölümü widget'ı
  Widget _buildTreatmentSection(String title, List<String> treatments) {
    final dim = context.dimensions;

    if (treatments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                title.contains('İlaç')
                    ? CupertinoIcons.capsule_fill
                    : title.contains('Biyolojik')
                        ? CupertinoIcons.leaf_arrow_circlepath
                        : CupertinoIcons.shield_fill,
                color: AppColors.primary,
                size: 16,
              ),
            ),
            SizedBox(width: dim.spaceS),
            SelectableText(
              title,
              style: AppTextTheme.captionL.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              toolbarOptions: const ToolbarOptions(
                copy: true,
                selectAll: true,
                cut: false,
                paste: false,
              ),
            ),
          ],
        ),
        SizedBox(height: dim.spaceS),
        ...treatments
            .map((treatment) => Padding(
                  padding: EdgeInsets.only(bottom: dim.spaceXS),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 6),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: dim.spaceS),
                      Expanded(
                        child: SelectableText(
                          treatment,
                          style: AppTextTheme.bodyText2.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: _currentFontSize,
                          ),
                          toolbarOptions: const ToolbarOptions(
                            copy: true,
                            selectAll: true,
                            cut: false,
                            paste: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ],
    );
  }

  Widget _buildHealthInfo(PlantAnalysisModel result) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dim = context.dimensions;

    // Kaldırılan Padding widget'ı yerine doğrudan Column döndürülüyor.
    // Bu Column'un yatay hizalaması, _buildResultScreen içindeki sarmalayıcı Padding tarafından yönetilecek.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Genel Bilgiler" Bölümü - Modern Apple Design
        Container(
          margin: EdgeInsets.only(bottom: dim.spaceL),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.05),
                AppColors.info.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      CupertinoIcons.chart_bar_alt_fill,
                      color: CupertinoColors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: dim.spaceM),
                  Expanded(
                    child: SelectableText(
                      'Analiz Sonuçları',
                      style: AppTextTheme.headline5.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      toolbarOptions: const ToolbarOptions(
                        copy: true,
                        selectAll: true,
                        cut: false,
                        paste: false,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.systemGrey4.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: FontSizeControl(
                      fontSizeLevel: _fontSizeLevel,
                      onFontSizeChanged: (int newLevel) {
                        setState(() {
                          _fontSizeLevel = newLevel;
                          _currentFontSize = _calculateFontSize(newLevel);
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: dim.spaceM),
              Divider(
                color: AppColors.primary.withOpacity(0.1),
                height: 1,
              ),
            ],
          ),
        ),

        // Genel bilgi kartı - modern tasarım
        Container(
          margin: EdgeInsets.only(bottom: dim.spaceL),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(dim.radiusL),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
              BoxShadow(
                color: CupertinoColors.systemGrey4.withOpacity(0.3),
                offset: Offset(0, 1),
                blurRadius: 3,
              ),
            ],
            border: Border.all(
              color: AppColors.primary.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sağlık Durumu Bölümü - Ana vurgu
              Container(
                padding: EdgeInsets.all(dim.paddingM),
                decoration: BoxDecoration(
                  color: result.getHealthStatusColor().withOpacity(0.08),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(dim.radiusL),
                    topRight: Radius.circular(dim.radiusL),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: result.getHealthStatusColor().withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: result.getHealthStatusColor().withOpacity(0.1),
                        border: Border.all(
                          color: result.getHealthStatusColor(),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          result.isHealthy
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.exclamationmark_circle_fill,
                          color: result.getHealthStatusColor(),
                          size: 24,
                        ),
                      ),
                    ),
                    SizedBox(width: dim.spaceM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: SelectableText(
                              'Sağlık Durumu',
                              style: AppTextTheme.captionL.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                fontSize: _currentFontSize *
                                    AppConstants.fontSizeMultiplierSmall,
                              ),
                              toolbarOptions: const ToolbarOptions(
                                copy: true,
                                selectAll: true,
                                cut: false,
                                paste: false,
                              ),
                            ),
                          ),
                          SizedBox(height: dim.spaceXXS),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: SelectableText(
                              result.getHealthStatusTitle(),
                              style: AppTextTheme.bodyText1.copyWith(
                                fontWeight: FontWeight.w600,
                                color: result.getHealthStatusColor(),
                                fontSize: _currentFontSize * 1.1,
                              ),
                              toolbarOptions: const ToolbarOptions(
                                copy: true,
                                selectAll: true,
                                cut: false,
                                paste: false,
                              ),
                            ),
                          ),
                          SizedBox(height: dim.spaceXS),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: SelectableText(
                              result.getHealthStatusDescription(),
                              style: AppTextTheme.bodyText2.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: _currentFontSize,
                              ),
                              toolbarOptions: const ToolbarOptions(
                                copy: true,
                                selectAll: true,
                                cut: false,
                                paste: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Diğer özet bilgiler burada eklenebilir
              // Örneğin: Son analiz tarihi, bitki türü, vb.
              Padding(
                padding: EdgeInsets.all(dim.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoCardItem(
                      icon: CupertinoIcons.calendar,
                      title: 'Son Analiz',
                      value: 'Bugün',
                      iconColor: CupertinoColors.systemTeal,
                    ),
                    SizedBox(height: dim.spaceM),
                    InfoCardItem(
                      icon: CupertinoIcons.leaf_arrow_circlepath,
                      title: 'Bitki Türü',
                      value: result.plantName,
                      iconColor: AppColors.primary,
                    ),

                    // Gelişim bilgileri _buildCareInfo içinde gösteriliyor, burada duplikasyon kaldırıldı
                  ],
                ),
              ),
            ],
          ),
        ),

        // "Tespit Edilen Hastalıklar" Bölümü - mevcut kod korundu
        if (result.diseases.isNotEmpty) ...[
          SizedBox(
              height: dim.spaceL), // Hastalıklar başlığı öncesi dikey boşluk
          Container(
            margin: EdgeInsets.only(
                bottom: dim.spaceM), // Başlık sonrası dikey boşluk
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    CupertinoIcons.exclamationmark_shield_fill,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: dim.spaceM),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    'Tespit Edilen Hastalıklar',
                    style: AppTextTheme.headline5.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    toolbarOptions: const ToolbarOptions(
                      copy: true,
                      selectAll: true,
                      cut: false,
                      paste: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...result.diseases.map((disease) {
            final severityColor = result.getDiseaseServerityColor(disease);
            final probability =
                (disease.probability != null ? disease.probability! * 100 : 0)
                    .toStringAsFixed(0);
            final severityText = result.getDiseaseServerityText(disease);

            return Container(
              margin: EdgeInsets.only(bottom: dim.spaceL),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    CupertinoColors.systemBackground,
                    severityColor.withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: severityColor.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: severityColor.withOpacity(0.15),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: severityColor.withOpacity(0.08),
                    highlightColor: severityColor.withOpacity(0.08),
                  ),
                  child: ExpansionTile(
                    iconColor: severityColor,
                    collapsedIconColor: severityColor.withOpacity(0.7),
                    backgroundColor: Colors.transparent,
                    collapsedBackgroundColor: Colors.transparent,
                    childrenPadding: EdgeInsets.zero,
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    tilePadding: EdgeInsets.all(20),
                    title: Row(
                      children: [
                        // Modern probability circle with gradient
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                severityColor,
                                severityColor.withOpacity(0.7),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: severityColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SelectableText(
                                  '$probability%',
                                  style: AppTextTheme.bodyText1.copyWith(
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  toolbarOptions: const ToolbarOptions(
                                    copy: true,
                                    selectAll: true,
                                    cut: false,
                                    paste: false,
                                  ),
                                ),
                                SelectableText(
                                  'risk',
                                  style: AppTextTheme.captionL.copyWith(
                                    color:
                                        CupertinoColors.white.withOpacity(0.9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  toolbarOptions: const ToolbarOptions(
                                    copy: true,
                                    selectAll: true,
                                    cut: false,
                                    paste: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: dim.spaceL),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                disease.name,
                                style: AppTextTheme.headline6.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                toolbarOptions: const ToolbarOptions(
                                  copy: true,
                                  selectAll: true,
                                  cut: false,
                                  paste: false,
                                ),
                              ),
                              SizedBox(height: dim.spaceXS),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      severityColor.withOpacity(0.15),
                                      severityColor.withOpacity(0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: severityColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: SelectableText(
                                  '${severityText} Şiddet',
                                  style: AppTextTheme.captionL.copyWith(
                                    color: severityColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  toolbarOptions: const ToolbarOptions(
                                    copy: true,
                                    selectAll: true,
                                    cut: false,
                                    paste: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Modern expand icon
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: severityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            CupertinoIcons.chevron_down,
                            color: severityColor,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    children: [
                      // Enhanced expanded content with glassmorphism
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              severityColor.withOpacity(0.03),
                              severityColor.withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        padding: EdgeInsets.all(20),
                        child: _buildExpandedDiseaseInfo(disease),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: CupertinoPageScaffold(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CupertinoActivityIndicator(radius: 16),
                const SizedBox(height: 16),
                SelectableText(
                  'Analiz sonucu yükleniyor...',
                  style: AppTextTheme.bodyText2.copyWith(
                    color: CupertinoColors.systemGrey,
                  ),
                  toolbarOptions: const ToolbarOptions(
                    copy: true,
                    selectAll: true,
                    cut: false,
                    paste: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const SelectableText('Analiz Sonucu Yüklenemedi'),
          leading: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(
              CupertinoIcons.back,
              color: Colors.black,
            ),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: CupertinoColors.systemRed,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const SelectableText('Hata oluştu',
                  style: AppTextTheme.headline5),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SelectableText(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTextTheme.bodyText2.copyWith(
                    color: CupertinoColors.systemGrey,
                  ),
                  toolbarOptions: const ToolbarOptions(
                    copy: true,
                    selectAll: true,
                    cut: false,
                    paste: false,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 160,
                child: AppButton(
                  text: 'Tekrar Dene',
                  onPressed: _loadAnalysisResult,
                  icon: CupertinoIcons.refresh,
                  type: AppButtonType.secondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final result = _currentAnalysisResult;
    if (result == null) {
      AppLogger.w(
          '🔍 BUILD: _currentAnalysisResult null! "Analiz Edilemedi" ekranı gösteriliyor');
      AppLogger.w(
          '🔍 BUILD: _isLoading: $_isLoading, _errorMessage: $_errorMessage');
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const SelectableText('Analiz Sonucu Bulunamadı'),
          leading: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(
              CupertinoIcons.back,
              color: Colors.black,
            ),
          ),
        ),
        child: const Center(child: SelectableText('Analiz sonucu bulunamadı')),
      );
    }

    return _buildResultScreen(context, result);
  }

  /// Analiz sonucu ekranını oluşturur - Modern Apple Design ile yeniden tasarlandı
  Widget _buildResultScreen(BuildContext context, PlantAnalysisModel result) {
    final dim = context.dimensions;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.8),
        border: const Border(),
        middle: SelectableText(
          result.fieldName != null && result.fieldName!.isNotEmpty
              ? result.fieldName!
              : result.plantName,
          style: AppTextTheme.headline6.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          toolbarOptions: const ToolbarOptions(
            copy: true,
            selectAll: true,
            cut: false,
            paste: false,
          ),
        ),
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.back,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            HapticFeedback.lightImpact();
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              CupertinoIcons.share,
              color: AppColors.primary,
              size: 18,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Hero Image Section - Glassmorphism effect
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    dim.paddingM,
                    dim.spaceM,
                    dim.paddingM,
                    0,
                  ),
                  child: _buildHeroImageSection(result, dim),
                ),
              ),

              // Plant Info Card - Modern gradient design
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: dim.paddingM),
                  child: _buildModernPlantInfoCard(result, dim),
                ),
              ),

              // Health Analysis Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: dim.paddingM,
                    vertical: dim.spaceL,
                  ),
                  child: _buildHealthInfo(result),
                ),
              ),

              // Care Information Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: dim.paddingM),
                  child: _buildCareInfo(result),
                ),
              ),

              // Advanced Agricultural Information
              if (_hasAdvancedAgriculturalInfo(result))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: dim.paddingM,
                      vertical: dim.spaceL,
                    ),
                    child: _buildAdvancedAgriculturalInfo(result),
                  ),
                ),

              // Bottom spacing
              SliverToBoxAdapter(
                child: SizedBox(height: dim.spaceXXL * 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modern Hero Image Section - Glassmorphism ve gradient efektleriyle
  Widget _buildHeroImageSection(PlantAnalysisModel result, dynamic dim) {
    return Hero(
      tag: 'plantImage_${result.plantName}',
      child: Container(
        height: dim.screenHeight * 0.4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, 16),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main Image
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: result.imageUrl.isNotEmpty
                    ? _buildImageWidget(result.imageUrl)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withOpacity(0.1),
                              AppColors.info.withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.leaf_arrow_circlepath,
                            size: 64,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),
            ),

            // Gradient Overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      CupertinoColors.black.withOpacity(0.3),
                      CupertinoColors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.5, 0.8, 1.0],
                  ),
                ),
              ),
            ),

            // Health Status Badge - Floating at top right
            Positioned(
              top: 16,
              right: 16,
              child: _buildFloatingHealthBadge(result),
            ),

            // Plant Name at Bottom
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    result.plantName,
                    style: AppTextTheme.headline4.copyWith(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: CupertinoColors.black.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    toolbarOptions: const ToolbarOptions(
                      copy: true,
                      selectAll: true,
                      cut: false,
                      paste: false,
                    ),
                  ),
                  if (result.location != null &&
                      result.location!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.location_solid,
                          size: 14,
                          color: CupertinoColors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SelectableText(
                            result.location!,
                            style: AppTextTheme.bodyText2.copyWith(
                              color: CupertinoColors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            toolbarOptions: const ToolbarOptions(
                              copy: true,
                              selectAll: true,
                              cut: false,
                              paste: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Floating Health Status Badge
  Widget _buildFloatingHealthBadge(PlantAnalysisModel result) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: result.getHealthStatusColor().withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CupertinoColors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            result.isHealthy
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.exclamationmark_triangle_fill,
            size: 16,
            color: CupertinoColors.white,
          ),
          const SizedBox(width: 4),
          SelectableText(
            result.isHealthy ? 'Sağlıklı' : 'Dikkat',
            style: AppTextTheme.captionL.copyWith(
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
            ),
            toolbarOptions: const ToolbarOptions(
              copy: true,
              selectAll: true,
              cut: false,
              paste: false,
            ),
          ),
        ],
      ),
    );
  }

  /// Modern Plant Info Card - Glassmorphism design
  Widget _buildModernPlantInfoCard(PlantAnalysisModel result, dynamic dim) {
    return Container(
      margin: EdgeInsets.only(top: dim.spaceL),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: CupertinoColors.systemGrey4.withOpacity(0.3),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with field name
          if (result.fieldName != null && result.fieldName!.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    CupertinoIcons.tag_fill,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    result.fieldName!,
                    style: AppTextTheme.headline6.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    toolbarOptions: const ToolbarOptions(
                      copy: true,
                      selectAll: true,
                      cut: false,
                      paste: false,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              color: AppColors.primary.withOpacity(0.1),
              height: 1,
            ),
            const SizedBox(height: 16),
          ],

          // Description Section
          _buildDescriptionSection(),
        ],
      ),
    );
  }

  /// Görüntüyü uygun şekilde oluşturur (base64 veya network)
  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64String = imageUrl.split(',')[1];
        final imageBytes = base64Decode(base64String);
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            AppLogger.e('Memory görüntü hatası: $error', error, stackTrace);
            return const Center(
              child: Icon(
                CupertinoIcons.photo,
                size: 64,
                color: CupertinoColors.systemGrey,
              ),
            );
          },
        );
      } catch (e) {
        AppLogger.e('Base64 görüntü decode hatası', e);
        return const Center(
          child: Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
        );
      }
    } else if (imageUrl.startsWith('file://')) {
      try {
        final filePath = imageUrl.replaceFirst('file://', '');

        return Image.file(
          File(filePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            AppLogger.e('Dosya görüntü hatası: $error', error, stackTrace);
            return const Center(
              child: Icon(
                CupertinoIcons.photo,
                size: 64,
                color: CupertinoColors.systemGrey,
              ),
            );
          },
        );
      } catch (e) {
        AppLogger.e('Dosya görüntü hatası', e);
        return const Center(
          child: Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
        );
      }
    } else {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return Center(
            child: CupertinoActivityIndicator(
              radius: 16,
              color: CupertinoColors.systemGrey,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          AppLogger.e('Network görüntü hatası: $error', error, stackTrace);
          return const Center(
            child: Icon(
              CupertinoIcons.photo,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
          );
        },
      );
    }
  }

  /// Sağlık durumu widget'ı
  Widget _buildHealthStatusWidget(PlantAnalysisModel result) {
    final dim = context.dimensions;
    return Container(
      margin: EdgeInsets.symmetric(vertical: dim.spaceL),
      width: double.infinity,
      padding: EdgeInsets.all(dim.paddingM),
      decoration: BoxDecoration(
        color: result.getHealthStatusColor().withOpacity(0.12),
        borderRadius: BorderRadius.circular(dim.radiusM),
        border: Border.all(
          color: result.getHealthStatusColor().withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(dim.paddingS),
            decoration: BoxDecoration(
              color: result.getHealthStatusColor().withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              result.isHealthy
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.exclamationmark_circle_fill,
              color: result.getHealthStatusColor(),
              size: dim.iconSizeM,
            ),
          ),
          SizedBox(width: dim.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  result.getHealthStatusTitle(),
                  style: AppTextTheme.caption.copyWith(
                    color: result.getHealthStatusColor(),
                    fontWeight: FontWeight.w600,
                  ),
                  toolbarOptions: const ToolbarOptions(
                    copy: true,
                    selectAll: true,
                    cut: false,
                    paste: false,
                  ),
                ),
                SizedBox(height: dim.spaceXXS),
                SelectableText(
                  result.getHealthStatusDescription(),
                  style: AppTextTheme.caption.copyWith(
                    color: result.getHealthStatusColor().withOpacity(0.8),
                  ),
                  toolbarOptions: const ToolbarOptions(
                    copy: true,
                    selectAll: true,
                    cut: false,
                    paste: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bakım bilgileri widget'ı
  Widget _buildCareInfo(PlantAnalysisModel result) {
    final dim = context.dimensions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gelişim skoru ve aşaması gösterimi
        () {
          final hasGrowthScore = result.growthScore != null;
          final hasGrowthStage = result.growthStage != null;
          final hasGrowthComment =
              result.growthComment != null && result.growthComment!.isNotEmpty;

          if (hasGrowthScore || hasGrowthStage || hasGrowthComment) {
            return Column(
              children: [
                _buildGrowthScoreWidget(result),
                SizedBox(height: dim.spaceL),
              ],
            );
          } else {
            return const SizedBox.shrink();
          }
        }(),

        // Bakım bilgileri - Sadece gerçek veri olan alanları göster
        () {
          final List<Widget> careItems = [];

          if (result.watering != null && result.watering!.isNotEmpty) {
            careItems.add(_buildCareItem(
              CupertinoIcons.drop_fill,
              'Sulama',
              result.watering!,
              AppColors.info,
            ));
          }

          if (result.sunlight != null && result.sunlight!.isNotEmpty) {
            if (careItems.isNotEmpty)
              careItems.add(SizedBox(height: dim.spaceM));
            careItems.add(_buildCareItem(
              CupertinoIcons.sun_max_fill,
              'Güneş Işığı',
              result.sunlight!,
              CupertinoColors.systemYellow,
            ));
          }

          if (result.soil != null && result.soil!.isNotEmpty) {
            if (careItems.isNotEmpty)
              careItems.add(SizedBox(height: dim.spaceM));
            careItems.add(_buildCareItem(
              CupertinoIcons.square_stack_3d_down_right_fill,
              'Toprak',
              result.soil!,
              CupertinoColors.systemBrown,
            ));
          }

          if (result.climate != null && result.climate!.isNotEmpty) {
            if (careItems.isNotEmpty)
              careItems.add(SizedBox(height: dim.spaceM));
            careItems.add(_buildCareItem(
              CupertinoIcons.cloud_sun_fill,
              'İklim',
              result.climate!,
              CupertinoColors.systemTeal,
            ));
          }

          // Tarımsal ipuçları varsa ekle
          if (result.agriculturalTips != null &&
              result.agriculturalTips!.isNotEmpty) {
            if (careItems.isNotEmpty)
              careItems.add(SizedBox(height: dim.spaceM));
            careItems.add(_buildCareItem(
              CupertinoIcons.leaf_arrow_circlepath,
              'Tarımsal İpuçları',
              result.agriculturalTips!.join(' • '),
              CupertinoColors.activeGreen,
            ));
          }

          // Müdahale yöntemleri varsa ekle
          if (result.interventionMethods != null &&
              result.interventionMethods!.isNotEmpty) {
            if (careItems.isNotEmpty)
              careItems.add(SizedBox(height: dim.spaceM));
            careItems.add(_buildCareItem(
              CupertinoIcons.gear_alt_fill,
              'Müdahale Yöntemleri',
              result.interventionMethods!.join(' • '),
              CupertinoColors.systemBlue,
            ));
          }

          // Eğer hiç bakım bilgisi yoksa bilgi mesajı göster
          if (careItems.isEmpty) {
            careItems.add(
              Container(
                padding: EdgeInsets.all(dim.paddingM),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(dim.radiusM),
                  border: Border.all(
                    color: CupertinoColors.systemBlue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.info_circle,
                      color: CupertinoColors.systemBlue,
                      size: 20,
                    ),
                    SizedBox(width: dim.spaceS),
                    Expanded(
                      child: SelectableText(
                        'Bu analiz için detaylı bakım bilgisi henüz mevcut değil. Genel bitki bakım kurallarını uygulayabilirsiniz.',
                        style: AppTextTheme.bodyText2.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: _currentFontSize * 0.95,
                        ),
                        toolbarOptions: const ToolbarOptions(
                          copy: true,
                          selectAll: true,
                          cut: false,
                          paste: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Bakım bilgileri konteynerı
            return Container(
              padding: EdgeInsets.all(dim.paddingM),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(dim.radiusL),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: careItems,
              ),
            );
          }

          return Column(children: careItems);
        }(),
      ],
    );
  }

  // Modern Bakım öğesi widget'ı - Apple design language ile
  Widget _buildCareItem(
      IconData icon, String title, String content, Color color) {
    final dim = context.dimensions;
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: dim.spaceM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color,
                  color.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: CupertinoColors.white,
              size: 24,
            ),
          ),
          SizedBox(width: dim.spaceL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  title,
                  style: AppTextTheme.headline6.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  toolbarOptions: const ToolbarOptions(
                    copy: true,
                    selectAll: true,
                    cut: false,
                    paste: false,
                  ),
                ),
                SizedBox(height: dim.spaceXS),
                SelectableText(
                  content,
                  style: AppTextTheme.bodyText2.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  toolbarOptions: const ToolbarOptions(
                    copy: true,
                    selectAll: true,
                    cut: false,
                    paste: false,
                  ),
                ),
              ],
            ),
          ),
          // Subtle decoration
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  /// Bitki açıklamasını oluşturan widget
  Widget _buildDescriptionSection() {
    final result = _currentAnalysisResult;
    if (result == null) return const SizedBox.shrink();

    String description = result.description;

    // JSON formatındaki açıklamayı temizle
    if (description.startsWith('{') && description.contains('"description"')) {
      try {
        final jsonData = json.decode(description);
        if (jsonData is Map<String, dynamic> &&
            jsonData.containsKey('description')) {
          description = jsonData['description'].toString();
        }
      } catch (e) {
        // JSON parse edilemezse orijinal metni kullan
        AppLogger.w('Description JSON parse hatası: $e');
      }
    }

    // Eğer açıklama boş veya çok kısaysa varsayılan açıklama kullan
    if (description.isEmpty || description.length < 10) {
      description =
          'Bu bitki analiz sonuçlarına göre değerlendirilmiştir. Detaylı bilgiler aşağıdaki bölümlerde yer almaktadır.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.info,
                color: AppColors.primary,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            SelectableText(
              "Hakkında",
              style: AppTextTheme.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              toolbarOptions: const ToolbarOptions(
                copy: true,
                selectAll: true,
                cut: false,
                paste: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          description,
          style: AppTextTheme.bodyText2.copyWith(
            fontSize: _currentFontSize,
            height: 1.5,
          ),
          toolbarOptions: const ToolbarOptions(
            copy: true,
            selectAll: true,
            cut: false,
            paste: false,
          ),
        ),
      ],
    );
  }

  // Yeni eklenen yardımcı metot - detay bölümü
  Widget _buildDetailSection({
    required IconData icon,
    required String title,
    required Color iconColor,
    required String content,
    bool selectable = false,
  }) {
    final dim = context.dimensions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon,
                size: 18,
                color: iconColor
                    .withOpacity(0.8)), // İkon boyutu ve opaklığı ayarlandı
            SizedBox(width: dim.spaceS),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SelectableText(
                title,
                style: AppTextTheme.bodyText1.copyWith(
                  // Stil güncellendi
                  fontWeight: FontWeight.w600, // Kalınlık arttırıldı
                  color: AppColors.textPrimary
                      .withOpacity(0.85), // Renk opaklığı ayarlandı
                  fontSize: _currentFontSize * 1.05, // Boyut ayarlandı
                ),
                toolbarOptions: const ToolbarOptions(
                  copy: true,
                  selectAll: true,
                  cut: false,
                  paste: false,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: dim.spaceS), // Boşluk arttırıldı
        Padding(
          padding: EdgeInsets.only(
              left: dim.spaceS, right: dim.spaceS), // İçerik için padding
          child: SelectableText(
            content,
            style: AppTextTheme.bodyText2.copyWith(
              color: AppColors.textPrimary
                  .withOpacity(0.75), // Renk opaklığı ayarlandı
              fontSize: _currentFontSize,
              height: 1.5, // Satır yüksekliği arttırıldı
            ),
            toolbarOptions: const ToolbarOptions(
              copy: true,
              selectAll: true,
              cut: false,
              paste: false,
            ),
          ),
        ),
        SizedBox(height: dim.spaceS), // Alt boşluk
      ],
    );
  }

  // Yeni eklenen yardımcı metot - metotlar listesi
  Widget _buildMethodsList({
    required IconData baseIcon, // baseIcon olarak değiştirildi
    required String title,
    required Color iconColor,
    required List<String> methods,
  }) {
    final dim = context.dimensions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(baseIcon,
                size: 18,
                color: iconColor.withOpacity(0.8)), // baseIcon kullanıldı
            SizedBox(width: dim.spaceS),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SelectableText(
                title,
                style: AppTextTheme.bodyText1.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary.withOpacity(0.85),
                  fontSize: _currentFontSize * 1.05,
                ),
                toolbarOptions: const ToolbarOptions(
                  copy: true,
                  selectAll: true,
                  cut: false,
                  paste: false,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: dim.spaceM), // Başlık ve liste arası boşluk arttırıldı
        ListView.separated(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: methods.length,
          separatorBuilder: (context, index) => Divider(
            height: dim.spaceM, // Öğeler arası boşluk arttırıldı
            thickness: 0.5,
            color: CupertinoColors.systemGrey4
                .withOpacity(0.3), // Daha ince ayırıcı
            indent: dim.spaceL, // Ayırıcı için girinti
            endIndent: dim.spaceS,
          ),
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.symmetric(
                  vertical: dim.spaceXS,
                  horizontal: dim.spaceS), // Liste öğesi padding'i
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    // Her öğe için baseIcon kullanılıyor
                    baseIcon,
                    size: 16,
                    color: iconColor.withOpacity(0.7),
                  ),
                  SizedBox(
                      width:
                          dim.spaceM), // İkon ve metin arası boşluk arttırıldı
                  Expanded(
                    child: SelectableText(
                      methods[index],
                      style: AppTextTheme.bodyText2.copyWith(
                        color: AppColors.textPrimary.withOpacity(0.75),
                        fontSize: _currentFontSize,
                        height: 1.5,
                      ),
                      toolbarOptions: const ToolbarOptions(
                        copy: true,
                        selectAll: true,
                        cut: false,
                        paste: false,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        SizedBox(height: dim.spaceS), // Alt boşluk
      ],
    );
  }

  // Tarih formatlamak için yardımcı metot
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Gelişmiş tarımsal bilgilerin var olup olmadığını kontrol eder
  bool _hasAdvancedAgriculturalInfo(PlantAnalysisModel result) {
    return result.diseaseName != null ||
        result.diseaseDescription != null ||
        result.treatmentName != null ||
        result.dosagePerDecare != null ||
        result.applicationMethod != null ||
        result.applicationTime != null ||
        result.applicationFrequency != null ||
        result.waitingPeriod != null ||
        result.effectiveness != null ||
        result.notes != null ||
        result.suggestion != null ||
        result.intervention != null ||
        result.agriculturalTip != null;
  }

  /// Gelişmiş tarımsal bilgiler bölümünü oluşturur
  Widget _buildAdvancedAgriculturalInfo(PlantAnalysisModel result) {
    final dim = context.dimensions;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(dim.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 2),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Container(
            padding: EdgeInsets.all(dim.paddingL),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(dim.radiusL),
                topRight: Radius.circular(dim.radiusL),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    CupertinoIcons.lab_flask_solid,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: dim.spaceM),
                SelectableText(
                  'Tespit Edilen Hastalıklar',
                  style: AppTextTheme.headline5.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  toolbarOptions: const ToolbarOptions(
                    copy: true,
                    selectAll: true,
                    cut: false,
                    paste: false,
                  ),
                ),
              ],
            ),
          ),

          // İçerik
          Padding(
            padding: EdgeInsets.all(dim.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hastalık Bilgileri
                if (result.diseaseName != null ||
                    result.diseaseDescription != null) ...[
                  _buildAgriculturalSection(
                    title: 'Hastalık Bilgileri',
                    icon: CupertinoIcons.exclamationmark_triangle_fill,
                    iconColor: AppColors.error,
                    items: [
                      if (result.diseaseName != null)
                        _buildAgriculturalItem(
                            'Hastalık Adı', result.diseaseName!),
                      if (result.diseaseDescription != null)
                        _buildAgriculturalItem(
                            'Açıklama', result.diseaseDescription!),
                    ],
                  ),
                  SizedBox(height: dim.spaceL),
                ],

                // Tedavi Bilgileri
                if (result.treatmentName != null ||
                    result.dosagePerDecare != null ||
                    result.applicationMethod != null ||
                    result.applicationTime != null ||
                    result.applicationFrequency != null ||
                    result.waitingPeriod != null ||
                    result.effectiveness != null) ...[
                  _buildAgriculturalSection(
                    title: 'Tedavi ve Uygulama',
                    icon: CupertinoIcons.bandage_fill,
                    iconColor: AppColors.info,
                    items: [
                      if (result.treatmentName != null)
                        _buildAgriculturalItem(
                            'Tedavi/İlaç', result.treatmentName!),
                      if (result.dosagePerDecare != null)
                        _buildAgriculturalItem(
                            'Dozaj (Dekar başına)', result.dosagePerDecare!),
                      if (result.applicationMethod != null)
                        _buildAgriculturalItem(
                            'Uygulama Yöntemi', result.applicationMethod!),
                      if (result.applicationTime != null)
                        _buildAgriculturalItem(
                            'Uygulama Zamanı', result.applicationTime!),
                      if (result.applicationFrequency != null)
                        _buildAgriculturalItem(
                            'Uygulama Sıklığı', result.applicationFrequency!),
                      if (result.waitingPeriod != null)
                        _buildAgriculturalItem(
                            'Bekleme Süresi', result.waitingPeriod!),
                      if (result.effectiveness != null)
                        _buildAgriculturalItem(
                            'Etkinlik', result.effectiveness!),
                    ],
                  ),
                  SizedBox(height: dim.spaceL),
                ],

                // Öneriler ve Notlar
                if (result.notes != null ||
                    result.suggestion != null ||
                    result.intervention != null ||
                    result.agriculturalTip != null) ...[
                  _buildAgriculturalSection(
                    title: 'Öneriler ve İpuçları',
                    icon: CupertinoIcons.lightbulb_fill,
                    iconColor: CupertinoColors.systemYellow,
                    items: [
                      if (result.suggestion != null)
                        _buildAgriculturalItem('Ana Öneri', result.suggestion!),
                      if (result.intervention != null)
                        _buildAgriculturalItem(
                            'Müdahale', result.intervention!),
                      if (result.agriculturalTip != null)
                        _buildAgriculturalItem(
                            'Tarımsal İpucu', result.agriculturalTip!),
                      if (result.notes != null)
                        _buildAgriculturalItem('Ek Notlar', result.notes!),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tarımsal bilgi bölümü oluşturucu
  Widget _buildAgriculturalSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> items,
  }) {
    final dim = context.dimensions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 16,
              ),
            ),
            SizedBox(width: dim.spaceS),
            SelectableText(
              title,
              style: AppTextTheme.bodyText1.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              toolbarOptions: const ToolbarOptions(
                copy: true,
                selectAll: true,
                cut: false,
                paste: false,
              ),
            ),
          ],
        ),
        SizedBox(height: dim.spaceM),
        ...items,
      ],
    );
  }

  /// Tarımsal bilgi item'ı oluşturucu
  Widget _buildAgriculturalItem(String label, String value) {
    final dim = context.dimensions;

    return Padding(
      padding: EdgeInsets.only(bottom: dim.spaceS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: dim.spaceS),
          Expanded(
            child: SelectableText.rich(
              TextSpan(
                style: AppTextTheme.bodyText2.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: _currentFontSize,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
              toolbarOptions: const ToolbarOptions(
                copy: true,
                selectAll: true,
                cut: false,
                paste: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
