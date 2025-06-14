import 'dart:async';
import 'dart:convert'; // Base64 için eklendi
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/theme/app_theme.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart'; // AppDimensions için import eklendi
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/plant_analysis/presentation/cubits/plant_analysis_cubit.dart';
import 'package:tatarai/features/plant_analysis/data/models/plant_analysis_result.dart';
import 'package:tatarai/features/plant_analysis/domain/entities/plant_analysis_entity.dart';
import 'package:tatarai/features/plant_analysis/data/models/disease_model.dart'
    as entity_disease;
import 'package:tatarai/features/plant_analysis/presentation/views/widgets/font_size_control.dart';
import 'package:tatarai/features/plant_analysis/presentation/views/widgets/info_card_item.dart';

part 'analysis_result_screen_mixin.dart';

/// PlantAnalysisResult için UI gösterimine yardımcı uzantılar
extension PlantAnalysisResultUIExtension on PlantAnalysisResult {
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
  const AnalysisResultScreen({super.key, required this.analysisId});

  /// Analiz ID'si
  final String analysisId;

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen>
    with SingleTickerProviderStateMixin, _AnalysisScreenResultMixin {
  // Analiz sonucunu local olarak tutmak için

  // Yazı tipi boyutu için _currentFontSize state içinde tanımlanmalı.
  // _AnalysisScreenResultMixin içinde initialize ediliyor olabilir veya burada edilebilir.
  // Örnek olarak burada başlangıç değeri atayalım:
  double _currentFontSize = AppTextTheme.bodyText2.fontSize ?? 14.0;

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
  Widget _buildHealthInfo(PlantAnalysisResult result) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dim = context.dimensions;

    // Kaldırılan Padding widget'ı yerine doğrudan Column döndürülüyor.
    // Bu Column'un yatay hizalaması, _buildResultScreen içindeki sarmalayıcı Padding tarafından yönetilecek.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Genel Bilgiler" Bölümü - Yeniden Tasarlandı
        Container(
          margin: EdgeInsets.only(bottom: dim.spaceM),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  CupertinoIcons.doc_chart_fill,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              SizedBox(width: dim.spaceM),
              Text(
                'Genel Bilgiler',
                style: AppTextTheme.headline5.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Spacer(),
              FontSizeControl(
                fontSizeLevel: _fontSizeLevel,
                onFontSizeChanged: (int newLevel) {
                  setState(() {
                    _fontSizeLevel = newLevel;
                    _currentFontSize = _calculateFontSize(newLevel);
                  });
                },
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
                                fontSize: _currentFontSize * 0.9,
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
                    if (result.growthStage != null &&
                        result.growthStage!.isNotEmpty) ...[
                      SizedBox(height: dim.spaceM),
                      InfoCardItem(
                        icon: CupertinoIcons.chart_bar_alt_fill,
                        title: 'Gelişim Aşaması',
                        value: result.growthStage!,
                        iconColor: CupertinoColors.activeOrange,
                      ),
                    ],
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
              margin: EdgeInsets.only(bottom: dim.spaceM),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(dim.radiusL),
                boxShadow: [
                  BoxShadow(
                    color: severityColor.withOpacity(0.08),
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
                  color: severityColor.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(dim.radiusL),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: severityColor.withOpacity(0.05),
                    highlightColor: severityColor.withOpacity(0.05),
                  ),
                  child: ExpansionTile(
                    iconColor: severityColor,
                    collapsedIconColor: severityColor.withOpacity(0.7),
                    backgroundColor: CupertinoColors.systemBackground,
                    collapsedBackgroundColor: CupertinoColors.systemBackground,
                    childrenPadding: EdgeInsets.zero,
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    tilePadding: EdgeInsets.symmetric(
                      horizontal: dim.paddingM,
                      vertical: dim.paddingM,
                    ),
                    title: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: severityColor.withOpacity(0.1),
                            border: Border.all(
                              color: severityColor,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: SelectableText(
                              '$probability%',
                              style: AppTextTheme.captionL.copyWith(
                                color: severityColor,
                                fontWeight: FontWeight.bold,
                                fontSize: dim.fontSizeXS,
                              ),
                              toolbarOptions: const ToolbarOptions(
                                copy: true,
                                selectAll: true,
                                cut: false,
                                paste: false,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: dim.spaceM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SelectableText(
                                disease.name,
                                style: AppTextTheme.bodyText1.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 2.3,
                                ),
                                toolbarOptions: const ToolbarOptions(
                                  copy: true,
                                  selectAll: true,
                                  cut: false,
                                  paste: false,
                                ),
                              ),
                              SizedBox(height: dim.spaceXXS),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: dim.paddingXS,
                                      vertical: dim.paddingXS,
                                    ),
                                    decoration: BoxDecoration(
                                      color: severityColor.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(dim.radiusXS),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: SelectableText(
                                        severityText,
                                        style: AppTextTheme.captionL.copyWith(
                                          color: severityColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: dim.fontSizeXS * 0.9,
                                        ),
                                        toolbarOptions: const ToolbarOptions(
                                          copy: true,
                                          selectAll: true,
                                          cut: false,
                                          paste: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: dim.spaceXS),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: SelectableText(
                                      'Şiddet Seviyesi',
                                      style: AppTextTheme.captionL.copyWith(
                                        color: AppColors.textSecondary,
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
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Container(
                        color: CupertinoColors.systemGrey6.withOpacity(0.3),
                        padding: EdgeInsets.only(
                            top: dim.paddingS,
                            bottom: dim.paddingM,
                            left: dim.paddingM,
                            right: dim.paddingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (disease.description != null &&
                                disease.description!.isNotEmpty) ...[
                              _buildDetailSection(
                                icon: CupertinoIcons.info_circle_fill,
                                title: 'Hastalık Detayları',
                                iconColor: CupertinoColors.systemIndigo,
                                content: disease.description!,
                                selectable: true,
                              ),
                              Divider(
                                  height: dim.spaceL,
                                  thickness: 0.5,
                                  color: CupertinoColors.systemGrey4
                                      .withOpacity(0.5)),
                            ],
                            if (disease.interventionMethods?.isNotEmpty ==
                                true) ...[
                              _buildMethodsList(
                                baseIcon: CupertinoIcons.wand_stars,
                                title: 'Önerilen Müdahale Yöntemleri',
                                iconColor: CupertinoColors.activeGreen,
                                methods: disease.interventionMethods!,
                              ),
                              if (disease.pesticideSuggestions?.isNotEmpty ==
                                  true)
                                Divider(
                                    height: dim.spaceL,
                                    thickness: 0.5,
                                    color: CupertinoColors.systemGrey4
                                        .withOpacity(0.5)),
                            ],
                            if (disease.pesticideSuggestions?.isNotEmpty ==
                                true) ...[
                              _buildMethodsList(
                                baseIcon: CupertinoIcons.bandage_fill,
                                title: 'Potansiyel İlaç Önerileri',
                                iconColor: AppColors.info,
                                methods: disease.pesticideSuggestions!,
                              ),
                            ],
                            if (disease.interventionMethods?.isEmpty ??
                                true &&
                                    disease.pesticideSuggestions?.isEmpty ==
                                        true)
                              Container(
                                margin: EdgeInsets.only(top: dim.spaceS),
                                padding: EdgeInsets.all(dim.paddingM),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemYellow
                                      .withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(dim.radiusM),
                                  border: Border.all(
                                    color: CupertinoColors.systemYellow
                                        .withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      CupertinoIcons
                                          .exclamationmark_triangle_fill,
                                      color: CupertinoColors.systemYellow
                                          .withOpacity(0.8),
                                      size: 20,
                                    ),
                                    SizedBox(width: dim.spaceS),
                                    Expanded(
                                      child: SelectableText(
                                        'Bu hastalık/sorun için özel müdahale veya ilaç önerisi bulunmamaktadır. Genel bitki sağlığı tavsiyelerine uyunuz.',
                                        style: AppTextTheme.bodyText2.copyWith(
                                          color: AppColors.textSecondary
                                              .withOpacity(0.9),
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
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
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
                Text(
                  'Analiz sonucu yükleniyor...',
                  style: AppTextTheme.bodyText2.copyWith(
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
          middle: const Text('Analiz Sonucu Yüklenemedi'),
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
              const Text('Hata oluştu', style: AppTextTheme.headline5),
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
          middle: const Text('Analiz Sonucu Bulunamadı'),
          leading: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(
              CupertinoIcons.back,
              color: Colors.black,
            ),
          ),
        ),
        child: const Center(child: Text('Analiz sonucu bulunamadı')),
      );
    }

    return _buildResultScreen(context, result);
  }

  /// Analiz sonucu ekranını oluşturur
  Widget _buildResultScreen(BuildContext context, PlantAnalysisResult result) {
    final dim = context.dimensions;
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
          child: const Icon(
            CupertinoIcons.back,
            color: Colors.black,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.share),
          onPressed: () {
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
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: dim.paddingM),
                  child: Hero(
                    tag: 'plantImage',
                    child: Container(
                      height: dim.screenHeight * 0.35,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(dim.radiusL),
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
                              borderRadius: BorderRadius.circular(dim.radiusL),
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
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: dim.paddingM),
                  child: _buildHealthStatusWidget(result),
                ),
                Container(
                  margin: EdgeInsets.fromLTRB(
                      dim.paddingM, dim.spaceM, dim.paddingM, dim.spaceS),
                  padding: EdgeInsets.all(dim.paddingL),
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
                      Text(
                        result.plantName,
                        style: AppTextTheme.headline3.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (result.location != null &&
                          result.location!.isNotEmpty) ...[
                        SizedBox(height: dim.spaceM),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.location_solid,
                                color: AppColors.primary,
                                size: 14,
                              ),
                            ),
                            SizedBox(width: dim.spaceS),
                            Expanded(
                              child: Text(
                                result.location!,
                                style: AppTextTheme.bodyText2.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (result.fieldName != null &&
                          result.fieldName!.isNotEmpty) ...[
                        SizedBox(height: dim.spaceM),
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
                            SizedBox(width: dim.spaceS),
                            Expanded(
                              child: Text(
                                "Tarla: ${result.fieldName!}",
                                style: AppTextTheme.bodyText2.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: dim.paddingL),
                      const Divider(height: 1),
                      SizedBox(height: dim.paddingL),
                      _buildDescriptionSection(),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: dim.paddingM, vertical: dim.spaceL),
                  child: _buildHealthInfo(result),
                ),
                if (result.watering != null ||
                    result.sunlight != null ||
                    result.growthStage != null) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(dim.paddingM, dim.paddingL,
                        dim.paddingM, dim.paddingXS),
                    child: Text(
                      'Gelişim Durumu ve Bakım Tavsiyeleri',
                      style: AppTextTheme.headline5.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: dim.fontSizeL,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: dim.paddingM),
                    child: _buildCareInfo(result),
                  ),
                ],
                if (result.suggestions.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      dim.paddingM,
                      dim.paddingL,
                      dim.paddingM,
                      dim.paddingXS,
                    ),
                    child: Text(
                      'Öneriler',
                      style: AppTextTheme.headline5.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: dim.fontSizeL,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: dim.paddingM,
                    ),
                    child: _buildSuggestionsList(result.suggestions),
                  ),
                ],
                if (result.similarImages.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(dim.paddingM, dim.paddingL,
                        dim.paddingM, dim.paddingXS),
                    child: Text(
                      'Benzer Bitkiler',
                      style: AppTextTheme.headline5.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: dim.fontSizeL,
                      ),
                    ),
                  ),
                  SizedBox(height: dim.spaceXS),
                  SizedBox(
                    height: dim.screenHeight * 0.18,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: dim.paddingM),
                      itemCount: result.similarImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: EdgeInsets.only(right: dim.spaceS),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(dim.radiusL),
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.systemGrey5
                                    .withOpacity(0.5),
                                blurRadius: dim.spaceXS,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(dim.radiusL),
                            child:
                                _buildImageWidget(result.similarImages[index]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dim.paddingM,
                    dim.paddingL,
                    dim.paddingM,
                    dim.paddingL,
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
  Widget _buildHealthStatusWidget(PlantAnalysisResult result) {
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
                Text(
                  result.getHealthStatusTitle(),
                  style: AppTextTheme.caption.copyWith(
                    color: result.getHealthStatusColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: dim.spaceXXS),
                Text(
                  result.getHealthStatusDescription(),
                  style: AppTextTheme.caption.copyWith(
                    color: result.getHealthStatusColor().withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          Divider(color: AppColors.primary.withOpacity(0.2), height: 1),
          SizedBox(height: context.dimensions.spaceM),
          ...suggestions.map((suggestion) => Container(
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
                      margin: const EdgeInsets.only(top: 2),
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
              )),
        ],
      ),
    );
  }

  // Gelişim skoru widget'ı
  Widget _buildGrowthScoreWidget(PlantAnalysisResult result) {
    if (result.growthScore == null) return const SizedBox.shrink();

    final score = result.growthScore!;
    final dim = context.dimensions;

    return Container(
      margin: EdgeInsets.only(bottom: dim.spaceL),
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
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.chart_bar_alt_fill,
                color: result.getGrowthScoreColor(score),
                size: dim.iconSizeM,
              ),
              SizedBox(width: dim.spaceS),
              Text(
                'Gelişim Skoru: $score/100',
                style: AppTextTheme.headline6.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: dim.spaceM),
          ClipRRect(
            borderRadius: BorderRadius.circular(dim.radiusS),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: CupertinoColors.systemGrey5,
              valueColor: AlwaysStoppedAnimation<Color>(
                result.getGrowthScoreColor(score),
              ),
              minHeight: 10,
            ),
          ),
          SizedBox(height: dim.spaceM),
          Text(
            result.getGrowthScoreText(score),
            style: AppTextTheme.bodyText2.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (result.growthStage != null && result.growthStage!.isNotEmpty) ...[
            SizedBox(height: dim.spaceM),
            const Divider(),
            SizedBox(height: dim.spaceM),
            Row(
              children: [
                Icon(
                  CupertinoIcons.leaf_arrow_circlepath,
                  color: AppColors.primary,
                  size: dim.iconSizeM,
                ),
                SizedBox(width: dim.spaceS),
                Flexible(
                  child: Text(
                    'Gelişim Aşaması: ${result.growthStage}',
                    style: AppTextTheme.bodyText1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            SizedBox(height: dim.spaceS),
            Text(
              result.getGrowthAdvice(
                score,
                null,
              ),
              style: AppTextTheme.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Bakım bilgileri widget'ı
  Widget _buildCareInfo(PlantAnalysisResult result) {
    final dim = context.dimensions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.growthScore != null) ...[
          _buildGrowthScoreWidget(result),
          SizedBox(height: dim.spaceL),
        ],
        Container(
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
            children: [
              if (result.watering != null && result.watering!.isNotEmpty) ...[
                _buildCareItem(
                  CupertinoIcons.drop_fill,
                  'Sulama',
                  result.watering!,
                  AppColors.info,
                ),
                SizedBox(height: dim.spaceM),
              ],
              if (result.sunlight != null && result.sunlight!.isNotEmpty) ...[
                _buildCareItem(
                  CupertinoIcons.sun_max_fill,
                  'Güneş Işığı',
                  result.sunlight!,
                  CupertinoColors.systemYellow,
                ),
                SizedBox(height: dim.spaceM),
              ],
              if (result.soil != null && result.soil!.isNotEmpty) ...[
                _buildCareItem(
                  CupertinoIcons.square_stack_3d_down_right_fill,
                  'Toprak',
                  result.soil!,
                  CupertinoColors.systemBrown,
                ),
                SizedBox(height: dim.spaceM),
              ],
              if (result.climate != null && result.climate!.isNotEmpty) ...[
                _buildCareItem(
                  CupertinoIcons.cloud_sun_fill,
                  'İklim',
                  result.climate!,
                  CupertinoColors.systemTeal,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Bakım öğesi widget'ı
  Widget _buildCareItem(
      IconData icon, String title, String content, Color color) {
    final dim = context.dimensions;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(dim.paddingS),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: dim.iconSizeS,
          ),
        ),
        SizedBox(width: dim.spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextTheme.bodyText1.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: dim.spaceXS),
              Text(
                content,
                style: AppTextTheme.bodyText2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Bitki açıklamasını oluşturan widget
  Widget _buildDescriptionSection() {
    final result = _analysisResult;
    if (result == null) return const SizedBox.shrink();

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
              style: AppTextTheme.caption.copyWith(
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
              child: Text(
                title,
                style: AppTextTheme.bodyText1.copyWith(
                  // Stil güncellendi
                  fontWeight: FontWeight.w600, // Kalınlık arttırıldı
                  color: AppColors.textPrimary
                      .withOpacity(0.85), // Renk opaklığı ayarlandı
                  fontSize: _currentFontSize * 1.05, // Boyut ayarlandı
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
              child: Text(
                title,
                style: AppTextTheme.bodyText1.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary.withOpacity(0.85),
                  fontSize: _currentFontSize * 1.05,
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
}
