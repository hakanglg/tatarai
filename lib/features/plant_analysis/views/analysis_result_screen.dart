import 'dart:async';
import 'dart:convert'; // Base64 için eklendi
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/theme/app_theme.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_cubit.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';
import 'package:tatarai/features/plant_analysis/views/widgets/font_size_control.dart';

/// Analiz sonuçları ekranı
/// Yapay zeka tarafından yapılan bitki analiz sonuçlarını gösterir
class AnalysisResultScreen extends StatefulWidget {
  /// Default constructor
  const AnalysisResultScreen({super.key, required this.analysisId});

  /// Analiz ID'si
  final String analysisId;

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen>
    with SingleTickerProviderStateMixin {
  // Analiz sonucunu local olarak tutmak için
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
      vsync: this,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: CupertinoPageScaffold(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoActivityIndicator(radius: 16),
                SizedBox(height: 16),
                Text(
                  'Analiz sonucu yükleniyor...',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey,
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
          middle: Text('Analiz Sonucu Yüklenemedi'),
          leading: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(
              CupertinoIcons.back,
              color: Colors.black, // Ok simgesinin rengi burada
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
              Text('Hata oluştu', style: AppTextTheme.headline5),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: AppTextTheme.bodyText2.copyWith(
                    color: CupertinoColors.systemGrey,
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

    final result = _analysisResult;
    if (result == null) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('Analiz Sonucu Bulunamadı'),
          leading: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(
              CupertinoIcons.back,
              color: Colors.black, // Ok simgesinin rengi burada
            ),
          ),
        ),
        child: Center(child: Text('Analiz sonucu bulunamadı')),
      );
    }

    return _buildResultScreen(context, result);
  }

  /// Analiz sonucu ekranını oluşturur
  Widget _buildResultScreen(BuildContext context, PlantAnalysisResult result) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          result.fieldName != null && result.fieldName!.isNotEmpty
              ? result.fieldName!
              : result.plantName,
        ),
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Icon(
            CupertinoIcons.back,
            color: Colors.black, // Ok simgesinin rengi burada
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.share),
          onPressed: () {
            // Paylaş fonksiyonu
            HapticFeedback.mediumImpact();
          },
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bitki görüntüsü - Hero animasyonu ile
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Hero(
                    tag: 'plantImage',
                    child: Container(
                      height: context.dimensions.screenHeight * 0.35,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.systemGrey4.withOpacity(0.2),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: result.imageUrl.isNotEmpty
                          ? ClipRRect(
                              // Köşeleri yuvarlatıldı - modern görünüm için
                              borderRadius: BorderRadius.circular(20),
                              child: _buildImageWidget(result.imageUrl),
                            )
                          : const Center(
                              child: Icon(
                                CupertinoIcons.photo,
                                size: 64,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                    ),
                  ),
                ),

                // Durum bildirimi - modern görünüm için güncellendi
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: result.isHealthy
                        ? CupertinoColors.systemGreen.withOpacity(0.12)
                        : CupertinoColors.systemRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: result.isHealthy
                          ? CupertinoColors.systemGreen.withOpacity(0.3)
                          : CupertinoColors.systemRed.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: result.isHealthy
                              ? CupertinoColors.systemGreen.withOpacity(0.2)
                              : CupertinoColors.systemRed.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          result.isHealthy
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.exclamationmark_circle_fill,
                          color: result.isHealthy
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.systemRed,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.isHealthy
                                  ? 'Bitkiniz Sağlıklı'
                                  : 'Sağlık Sorunu Tespit Edildi',
                              style: AppTextTheme.subtitle1.copyWith(
                                color: result.isHealthy
                                    ? CupertinoColors.systemGreen
                                    : CupertinoColors.systemRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              result.isHealthy
                                  ? 'Bitkiniz iyi durumda görünüyor'
                                  : 'Bitkinizde bazı sorunlar tespit edildi',
                              style: AppTextTheme.caption.copyWith(
                                color: result.isHealthy
                                    ? CupertinoColors.systemGreen
                                        .withOpacity(0.8)
                                    : CupertinoColors.systemRed.withOpacity(
                                        0.8,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Ana bilgiler kartı - modern görünüm için güncellendi
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.systemGrey5.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bitki adı
                      Text(
                        result.plantName,
                        style: AppTextTheme.headline3.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      // Konum bilgisi
                      if (result.location != null &&
                          result.location!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.location_solid,
                                color: AppColors.secondary,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                result.location!,
                                style: AppTextTheme.bodyText2.copyWith(
                                  color: CupertinoColors.systemGrey,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Tarla adı
                      if (result.fieldName != null &&
                          result.fieldName!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.tag_fill,
                                color: AppColors.primary,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Tarla: ${result.fieldName!}",
                                style: AppTextTheme.bodyText2.copyWith(
                                  color: CupertinoColors.systemGrey,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 18),

                      // Bitki açıklaması
                      _buildDescriptionSection(),
                    ],
                  ),
                ),

                // Hastalık bilgileri - modern görünüm için güncellendi
                if (result.diseases.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      'Tespit Edilen Hastalıklar',
                      style: AppTextTheme.headline5.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildHealthInfo(result),
                  ),
                ],

                // Bakım bilgileri - modern görünüm için güncellendi
                if (result.watering != null ||
                    result.sunlight != null ||
                    result.growthStage != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      'Gelişim Durumu ve Bakım Tavsiyeleri',
                      style: AppTextTheme.headline5.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildCareInfo(result),
                  ),
                ],

                // Öneriler - modern görünüm için güncellendi
                if (result.suggestions.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.dimensions.paddingM,
                      context.dimensions.paddingL,
                      context.dimensions.paddingM,
                      context.dimensions.paddingXS,
                    ),
                    child: Text(
                      'Öneriler',
                      style: AppTextTheme.headline5.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: context.dimensions.fontSizeL,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.dimensions.paddingM,
                    ),
                    child: _buildSuggestionsList(result.suggestions),
                  ),
                ],

                // Benzer Görüntüler - modern görünüm için güncellendi
                if (result.similarImages.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        context.dimensions.paddingM,
                        context.dimensions.paddingL,
                        context.dimensions.paddingM,
                        context.dimensions.paddingXS),
                    child: Text(
                      'Benzer Bitkiler',
                      style: AppTextTheme.headline5.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: context.dimensions.fontSizeL,
                      ),
                    ),
                  ),
                  SizedBox(height: context.dimensions.spaceXS),
                  SizedBox(
                    height: context.dimensions.screenHeight * 0.18,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                          horizontal: context.dimensions.paddingM),
                      itemCount: result.similarImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin:
                              EdgeInsets.only(right: context.dimensions.spaceS),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                context.dimensions.radiusL),
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.systemGrey5
                                    .withOpacity(0.5),
                                blurRadius: context.dimensions.spaceXS,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                                context.dimensions.radiusL),
                            child:
                                _buildImageWidget(result.similarImages[index]),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // Tek buton - "Yeni Analiz" butonu
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.dimensions.paddingM,
                    context.dimensions.paddingL,
                    context.dimensions.paddingM,
                    context.dimensions.paddingL,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      text: 'Yeni Analiz',
                      icon: CupertinoIcons.camera_fill,
                      type: AppButtonType.primary,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Görüntüyü uygun şekilde oluşturur (base64 veya network)
  Widget _buildImageWidget(String imageUrl) {
    // Base64 formatındaysa
    if (imageUrl.startsWith('data:image')) {
      try {
        // Base64 formatındaki "data:image/jpeg;base64," kısmını çıkar
        final base64String = imageUrl.split(',')[1];
        // Base64'ten decode et
        final imageBytes = base64Decode(base64String);
        // Memory image olarak göster
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
    }
    // Yerel dosya yolu ise
    else if (imageUrl.startsWith('file://')) {
      try {
        // file:// önekini kaldır
        final filePath = imageUrl.replaceFirst('file://', '');
        // Dosyadan yükle
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
    }
    // Normal URL ise ağdan yükle
    else {
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

  // Sağlık bilgileri - modern görünüm için güncellendi
  Widget _buildHealthInfo(PlantAnalysisResult result) {
    if (result.diseases.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: CupertinoColors.systemGreen.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: CupertinoColors.systemGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bitkinizde herhangi bir hastalık belirtisi bulunmuyor.',
                style: AppTextTheme.bodyText2.copyWith(
                  color: CupertinoColors.systemGreen,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: result.diseases.map((disease) {
        final severity = disease.probability >= 0.7
            ? 'Yüksek'
            : disease.probability >= 0.4
                ? 'Orta'
                : 'Düşük';

        final severityColor = disease.probability >= 0.7
            ? CupertinoColors.systemRed
            : disease.probability >= 0.4
                ? CupertinoColors.systemYellow
                : CupertinoColors.systemGreen;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: severityColor.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: severityColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: severityColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            color: severityColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            disease.name,
                            style: AppTextTheme.headline6.copyWith(
                              color: severityColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Şiddet: $severity',
                      style: AppTextTheme.caption.copyWith(
                        color: severityColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (disease.description != null &&
                  disease.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  disease.description!,
                  style: AppTextTheme.bodyText2.copyWith(
                    color: CupertinoColors.systemGrey,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  // Öneriler listesi - modern görünüm için güncellendi
  Widget _buildSuggestionsList(List<String> suggestions) {
    return Container(
      padding: EdgeInsets.all(context.dimensions.paddingL),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey5.withOpacity(0.5),
            blurRadius: context.dimensions.radiusL,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve FontSizeControl yan yana
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FontSizeControl(
                fontSizeLevel: _fontSizeLevel,
                onFontSizeChanged: (newLevel) {
                  setState(() {
                    _fontSizeLevel = newLevel;
                  });
                },
                labelText: 'Yazı',
              ),
            ],
          ),
          SizedBox(height: context.dimensions.spaceM),
          // Çizgi ekle
          Divider(color: AppColors.primary.withOpacity(0.2), height: 1),
          SizedBox(height: context.dimensions.spaceM),
          ...suggestions
              .map((suggestion) => Container(
                    margin: EdgeInsets.only(bottom: context.dimensions.spaceM),
                    padding: EdgeInsets.all(context.dimensions.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.07),
                      borderRadius:
                          BorderRadius.circular(context.dimensions.radiusM),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            CupertinoIcons.leaf_arrow_circlepath,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: context.dimensions.spaceM),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: AppTextTheme.bodyText1.copyWith(
                              height: 1.5,
                              fontSize: context.dimensions.fontSizeM +
                                  (_fontSizeLevel * 2),
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  // Bakım bilgileri - modern görünüm için güncellendi
  Widget _buildCareInfo(PlantAnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey5.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gelişim durumu ve yorumu
          if (result.growthStage != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.chart_bar_alt_fill,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gelişim Aşaması',
                        style: AppTextTheme.headline6.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result.growthStage!,
                        style: AppTextTheme.bodyText2.copyWith(
                          color: CupertinoColors.systemGrey,
                          height: 1.4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (result.growthScore != null) ...[
                        const SizedBox(height: 10),
                        _buildGrowthScoreIndicator(result.growthScore!),
                        const SizedBox(height: 8),
                        Text(
                          _getGrowthScoreText(result.growthScore!),
                          style: AppTextTheme.bodyText2.copyWith(
                            color: CupertinoColors.systemGrey,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getGrowthAdvice(
                              result.growthScore!, result.growthStage),
                          style: AppTextTheme.bodyText2.copyWith(
                            color: _getGrowthScoreColor(result.growthScore!),
                            height: 1.4,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (result.watering != null || result.sunlight != null) ...[
              const SizedBox(height: 24),
              Divider(height: 1),
              const SizedBox(height: 24),
            ],
          ],

          if (result.watering != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.drop_fill,
                    color: AppColors.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sulama',
                        style: AppTextTheme.headline6.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result.watering!,
                        style: AppTextTheme.bodyText2.copyWith(
                          color: CupertinoColors.systemGrey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (result.sunlight != null) ...[
              const SizedBox(height: 24),
              Divider(height: 1),
              const SizedBox(height: 24),
            ],
          ],
          if (result.sunlight != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.sun_max_fill,
                    color: AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Işık İhtiyacı',
                        style: AppTextTheme.headline6.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result.sunlight!,
                        style: AppTextTheme.bodyText2.copyWith(
                          color: CupertinoColors.systemGrey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          // Isı ihtiyacı eklenebilir (eğer API'den geliyorsa)
        ],
      ),
    );
  }

  /// Gelişim durumuna göre tavsiye metni döndürür
  String _getGrowthAdvice(int score, String? stage) {
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

  /// Bitki açıklamasını oluşturan widget
  Widget _buildDescriptionSection() {
    final result = _analysisResult;
    if (result == null) return const SizedBox.shrink();

    // Konum bilgisini içermeyen bir açıklama oluştur
    String description = result.description;

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
            Text(
              "Hakkında",
              style: AppTextTheme.subtitle1.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: AppTextTheme.bodyText2,
        ),
      ],
    );
  }

  /// Gelişim skorunu gösteren widget
  Widget _buildGrowthScoreIndicator(int score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getGrowthScoreColor(score),
                  ),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$score/100',
              style: AppTextTheme.bodyText2.copyWith(
                fontWeight: FontWeight.bold,
                color: _getGrowthScoreColor(score),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Gelişim skoruna göre renk döndürür
  Color _getGrowthScoreColor(int score) {
    if (score >= 80) {
      return CupertinoColors.systemGreen;
    } else if (score >= 60) {
      return AppColors.info;
    } else if (score >= 40) {
      return CupertinoColors.systemYellow;
    } else if (score >= 20) {
      return CupertinoColors.systemOrange;
    } else {
      return CupertinoColors.systemRed;
    }
  }

  /// Gelişim skoruna göre açıklama metni döndürür
  String _getGrowthScoreText(int score) {
    if (score >= 80) {
      return 'Bitkinin gelişimi mükemmel, ideal koşullarda büyüyor.';
    } else if (score >= 60) {
      return 'Bitkinin gelişimi iyi durumda, büyüme devam ediyor.';
    } else if (score >= 40) {
      return 'Ortalama bir gelişim gösteriyor, bakım koşulları iyileştirilebilir.';
    } else if (score >= 20) {
      return 'Gelişim yavaş, acil bakım ve müdahale gerekebilir.';
    } else {
      return 'Kritik gelişim seviyesi, acil müdahale gerekiyor.';
    }
  }
}
