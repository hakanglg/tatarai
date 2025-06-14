import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/plant_analysis/data/models/plant_analysis_result.dart';
import 'package:tatarai/features/plant_analysis/presentation/views/analyses_result/analysis_result_screen.dart';

/// Analiz kartı widget'ı
///
/// Ana ekrandaki son analizler ve tüm analizler ekranında kullanılan
/// ortak analiz kartı görünümü widget'ı
class AnalysisCard extends StatelessWidget {
  /// Gösterilecek analiz verisi
  final PlantAnalysisResult analysis;

  /// Kart boyutu türü - kompakt (ana ekran) veya geniş (analiz listesi)
  final AnalysisCardSize cardSize;

  /// Tarih etiketi metni
  final String? dateLabel;

  /// Karta tıklandığında çalışacak fonksiyon
  final VoidCallback? onTap;

  /// Varsayılan yapıcı metod
  const AnalysisCard({
    super.key,
    required this.analysis,
    this.cardSize = AnalysisCardSize.compact,
    this.dateLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => AnalysisResultScreen(
                  analysisId: analysis.id,
                ),
              ),
            );
          },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(
              cardSize == AnalysisCardSize.compact
                  ? context.dimensions.radiusM
                  : context.dimensions.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
              cardSize == AnalysisCardSize.compact
                  ? context.dimensions.radiusM
                  : context.dimensions.radiusL),
          child: _buildCardContent(context),
        ),
      ),
    );
  }

  /// Kart içeriği
  Widget _buildCardContent(BuildContext context) {
    switch (cardSize) {
      case AnalysisCardSize.compact:
        return _buildCompactCard(context);
      case AnalysisCardSize.large:
        return _buildLargeCard(context);
    }
  }

  /// Kompakt kart (ana ekran için)
  Widget _buildCompactCard(BuildContext context) {
    // Sağlık durumu renklerini belirle
    final Color statusColor = analysis.diseases.isEmpty
        ? AppColors.primary
        : CupertinoColors.systemRed;

    // Sağlık durumu metni
    final String statusText =
        analysis.diseases.isEmpty ? 'Sağlıklı' : analysis.diseases.first.name;

    return Stack(
      children: [
        // Ana içerik
        Padding(
          padding: EdgeInsets.all(context.dimensions.paddingM),
          child: Row(
            children: [
              // Analiz fotoğrafı
              _buildImageContainer(context, compact: true),
              SizedBox(width: context.dimensions.spaceM),

              // İçerik
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık
                    Text(
                      analysis.plantName ?? 'Bilinmeyen Bitki',
                      style: AppTextTheme.headline6.copyWith(
                        fontSize: context.dimensions.fontSizeM,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 6),

                    // Durum göstergesi
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            analysis.diseases.isEmpty
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.exclamationmark_circle_fill,
                            size: 12,
                            color: statusColor,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              statusText,
                              style: AppTextTheme.caption.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: context.dimensions.fontSizeXS,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tarih ve tür bilgisi
                    if (analysis.fieldName != null &&
                        analysis.fieldName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Tarla: ${analysis.fieldName}',
                          style: AppTextTheme.bodyText2.copyWith(
                            color: CupertinoColors.systemGrey,
                            fontSize: context.dimensions.fontSizeXS,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),

              // Ok işareti
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  color: CupertinoColors.systemGrey,
                  size: 12,
                ),
              ),
            ],
          ),
        ),

        // Tarih etiketi
        if (dateLabel != null)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                dateLabel!,
                style: AppTextTheme.caption.copyWith(
                  color: CupertinoColors.systemGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Büyük kart (tüm analizler ekranı için)
  Widget _buildLargeCard(BuildContext context) {
    final fieldName =
        analysis.fieldName != null && analysis.fieldName!.isNotEmpty
            ? analysis.fieldName!
            : null;

    // Sağlık durumu renklerini belirle
    final Color statusColor = analysis.diseases.isEmpty
        ? AppColors.primary
        : CupertinoColors.systemRed;

    // Sağlık durumu metni
    final String statusText =
        analysis.diseases.isEmpty ? 'Sağlıklı' : analysis.diseases.first.name;

    return Padding(
      padding: EdgeInsets.all(context.dimensions.paddingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Analiz fotoğrafı
          Hero(
            tag: 'analysis_image_${analysis.id}',
            child: Container(
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.dimensions.radiusM),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey5,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Fotoğraf
                  analysis.imageUrl.isNotEmpty
                      ? _buildAnalysisImage(analysis.imageUrl)
                      : Container(
                          color: CupertinoColors.systemGrey6,
                          child: Icon(
                            CupertinoIcons.photo,
                            color: CupertinoColors.systemGrey,
                            size: 32,
                          ),
                        ),

                  // Sağlık durumu göstergesi
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: CupertinoColors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withOpacity(0.2),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          analysis.diseases.isEmpty
                              ? CupertinoIcons.checkmark
                              : CupertinoIcons.exclamationmark,
                          color: CupertinoColors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: context.dimensions.spaceM),

          // Ana içerik
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ana başlık - Tarla adı veya bitki adı
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fieldName ?? analysis.plantName,
                        style: AppTextTheme.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (dateLabel != null)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          dateLabel!,
                          style: AppTextTheme.caption.copyWith(
                            color: CupertinoColors.systemGrey,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4),

                // Alt başlık - Bitki adı veya hastalık durumu
                if (fieldName != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.leaf_arrow_circlepath,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          analysis.plantName,
                          style: AppTextTheme.bodyText2.copyWith(
                            color: CupertinoColors.systemGrey,
                            fontSize: context.dimensions.fontSizeXS,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                SizedBox(height: 4),

                // Durum etiketi - flexible width
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.5,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        analysis.diseases.isEmpty
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.exclamationmark_circle_fill,
                        size: 10,
                        color: statusColor,
                      ),
                      SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          statusText,
                          style: AppTextTheme.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Konum veya ek bilgi
                if (analysis.location != null && analysis.location!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.location,
                          size: 10,
                          color: CupertinoColors.systemGrey,
                        ),
                        SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            analysis.location!,
                            style: AppTextTheme.caption.copyWith(
                              color: CupertinoColors.systemGrey,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(width: 8),

          // İleri oku
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
              size: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Görüntü konteyneri
  Widget _buildImageContainer(BuildContext context, {required bool compact}) {
    final double size = compact ? 65 : context.dimensions.buttonHeight * 1.8;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(compact
              ? context.dimensions.radiusM
              : context.dimensions.radiusL),
          bottomLeft: Radius.circular(compact
              ? context.dimensions.radiusM
              : context.dimensions.radiusL),
          topRight: compact
              ? Radius.circular(context.dimensions.radiusS)
              : Radius.zero,
          bottomRight: compact
              ? Radius.circular(context.dimensions.radiusS)
              : Radius.zero,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey5,
            blurRadius: 3,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Görüntü
          analysis.imageUrl.isNotEmpty
              ? _buildAnalysisImage(analysis.imageUrl)
              : Container(
                  color: CupertinoColors.systemGrey6,
                  child: Icon(
                    CupertinoIcons.photo,
                    color: CupertinoColors.systemGrey,
                    size: compact ? 24 : 32,
                  ),
                ),

          // Sağlık durumu göstergesi
          if (!compact)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: analysis.diseases.isEmpty
                      ? AppColors.primary
                      : CupertinoColors.systemRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  analysis.diseases.isEmpty
                      ? CupertinoIcons.checkmark
                      : CupertinoIcons.exclamationmark,
                  color: CupertinoColors.white,
                  size: 14,
                ),
              ),
            ),

          // Görüntü üstünde ince bir gradient gölge
          if (analysis.imageUrl.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: compact ? 20 : 40,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Analiz fotoğrafı için image widget'ı
  Widget _buildAnalysisImage(String imageUrl) {
    // Base64 ile kodlanmış bir görüntü ise
    if (imageUrl.startsWith('data:image')) {
      try {
        // Base64 veriyi ayır
        final dataUri = Uri.parse(imageUrl);
        final mimeType = dataUri.pathSegments.first.split(':').last;
        final data = dataUri.data!.contentAsBytes();
        // Decode ederek kullan
        return Image.memory(
          data,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            AppLogger.e('Base64 görüntü hatası: $error', error, stackTrace);
            return const Icon(
              CupertinoIcons.photo,
              size: 24,
              color: CupertinoColors.systemGrey,
            );
          },
        );
      } catch (e) {
        AppLogger.e('Base64 görüntü hatası', e);
        return const Icon(
          CupertinoIcons.photo,
          size: 24,
          color: CupertinoColors.systemGrey,
        );
      }
    }
    // Dosya yolu ise
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
            return const Icon(
              CupertinoIcons.photo,
              size: 24,
              color: CupertinoColors.systemGrey,
            );
          },
        );
      } catch (e) {
        AppLogger.e('Dosya görüntü hatası', e);
        return const Icon(
          CupertinoIcons.photo,
          size: 24,
          color: CupertinoColors.systemGrey,
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
          return const Center(
            child: CupertinoActivityIndicator(
              radius: 10,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          AppLogger.e('Network görüntü hatası: $error', error, stackTrace);
          return const Icon(
            CupertinoIcons.photo,
            size: 24,
            color: CupertinoColors.systemGrey,
          );
        },
      );
    }
  }
}

/// Analiz kartı boyut türleri
enum AnalysisCardSize {
  /// Kompakt boyut - Ana ekranda kullanılan kart
  compact,

  /// Büyük boyut - Tüm analizler ekranında kullanılan kart
  large,
}
