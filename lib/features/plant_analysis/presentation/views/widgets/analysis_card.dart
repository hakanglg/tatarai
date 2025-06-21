import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/plant_analysis/data/models/plant_analysis_model.dart';
import 'package:tatarai/features/plant_analysis/presentation/views/analyses_result/analysis_result_screen.dart';

/// Analiz kartı widget'ı
///
/// Ana ekrandaki son analizler ve tüm analizler ekranında kullanılan
/// ortak analiz kartı görünümü widget'ı
class AnalysisCard extends StatelessWidget {
  /// Gösterilecek analiz verisi
  final PlantAnalysisModel analysis;

  /// Kart boyutu türü - kompakt (ana ekran) veya geniş (analiz listesi)
  final AnalysisCardSize cardSize;

  /// Tarih etiketi metni
  final String? dateLabel;

  /// Karta tıklandığında çalışacak fonksiyon
  final VoidCallback? onTap;

  /// Analiz silindiğinde çalışacak fonksiyon
  final VoidCallback? onDelete;

  /// Silme butonunu göster/gizle
  final bool showDeleteButton;

  /// Varsayılan yapıcı metod
  const AnalysisCard({
    super.key,
    required this.analysis,
    this.cardSize = AnalysisCardSize.compact,
    this.dateLabel,
    this.onTap,
    this.onDelete,
    this.showDeleteButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(cardSize == AnalysisCardSize.compact
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
        borderRadius: BorderRadius.circular(cardSize == AnalysisCardSize.compact
            ? context.dimensions.radiusM
            : context.dimensions.radiusL),
        child: _buildCardContent(context),
      ),
    );

    // Swipe-to-delete özelliği varsa Dismissible ile sar
    if (showDeleteButton && onDelete != null) {
      return Dismissible(
        key: Key('analysis_${analysis.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmation(context);
        },
        onDismissed: (direction) {
          onDelete?.call();
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: CupertinoColors.systemRed,
            borderRadius: BorderRadius.circular(
                cardSize == AnalysisCardSize.compact
                    ? context.dimensions.radiusM
                    : context.dimensions.radiusL),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                CupertinoIcons.delete,
                color: CupertinoColors.white,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'delete'.locale(context),
                style: AppTextTheme.bodyText1.copyWith(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        child: GestureDetector(
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
          child: cardContent,
        ),
      );
    }

    // Normal kart
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
      child: cardContent,
    );
  }

  /// Silme onayı dialog'unu gösterir
  Future<bool?> _showDeleteConfirmation(BuildContext context) async {
    return await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(
            'delete_analysis'.locale(context),
            style: AppTextTheme.headline6.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'delete_analysis_confirmation'.locale(context),
              style: AppTextTheme.bodyText2.copyWith(
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(
                'cancel'.locale(context),
                style: AppTextTheme.bodyText1.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(
                'delete'.locale(context),
                style: AppTextTheme.bodyText1.copyWith(
                  color: CupertinoColors.systemRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
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
    // Sağlık durumu renklerini belirle - isHealthy alanına göre
    final Color statusColor =
        analysis.isHealthy ? AppColors.primary : CupertinoColors.systemRed;

    // Sağlık durumu metni - isHealthy alanına göre
    final String statusText = analysis.isHealthy
        ? 'Sağlıklı'
        : (analysis.diseases.isNotEmpty
            ? analysis.diseases.first.name
            : 'Sağlık Sorunu');

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
                    // Başlık - tarla adı varsa onu, yoksa bitki adını göster
                    Text(
                      (analysis.fieldName?.isNotEmpty ?? false)
                          ? analysis.fieldName!
                          : (analysis.plantName ?? 'Bilinmeyen Bitki'),
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
                            analysis.isHealthy
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

                    // Alt bilgi - analiz tarihi
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _formatAnalysisDate(context),
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

    // Sağlık durumu renklerini belirle - isHealthy alanına göre
    final Color statusColor =
        analysis.isHealthy ? AppColors.primary : CupertinoColors.systemRed;

    // Sağlık durumu metni - isHealthy alanına göre
    final String statusText = analysis.isHealthy
        ? 'healthy'.locale(context)
        : (analysis.diseases.isNotEmpty
            ? analysis.diseases.first.name
            : 'health_issue'.locale(context));

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
                          analysis.isHealthy
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
                // Ana başlık - Tarla adı varsa onu, yoksa bitki adını göster
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (analysis.fieldName?.isNotEmpty ?? false)
                            ? analysis.fieldName!
                            : (analysis.plantName ??
                                'unknown_plant'.locale(context)),
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

                // Alt başlık - title'da tarla adı varsa bitki adını göster
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
                        _formatAnalysisDate(context),
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
                        analysis.isHealthy
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

  /// Analiz tarihini formatlar
  String _formatAnalysisDate(BuildContext context) {
    if (analysis.timestamp == null) {
      return 'analysis_date_unknown'.locale(context);
    }

    try {
      final date = DateTime.fromMillisecondsSinceEpoch(analysis.timestamp!);
      final now = DateTime.now();
      final difference = now.difference(date);

      // Bugün yapıldıysa
      if (difference.inDays == 0) {
        final formatter = DateFormat('HH:mm');
        return '${'today'.locale(context)} ${formatter.format(date)}';
      }
      // Dün yapıldıysa
      else if (difference.inDays == 1) {
        final formatter = DateFormat('HH:mm');
        return '${'yesterday'.locale(context)} ${formatter.format(date)}';
      }
      // Bu hafta yapıldıysa
      else if (difference.inDays < 7) {
        return '${difference.inDays} ${'days_ago'.locale(context)}';
      }
      // Daha eskiyse
      else {
        final formatter = DateFormat('dd.MM.yyyy');
        return formatter.format(date);
      }
    } catch (e) {
      AppLogger.e('Tarih formatlama hatası', e);
      return 'analysis_date_unknown'.locale(context);
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
