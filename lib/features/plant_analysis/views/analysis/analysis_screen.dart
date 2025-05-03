import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tatarai/core/utils/permission_manager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/widgets/app_dialog_manager.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_cubit.dart';
import 'package:tatarai/features/plant_analysis/models/location_models.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_state.dart';
import 'package:tatarai/features/plant_analysis/services/location_service.dart';
import 'package:tatarai/features/plant_analysis/views/analyses_result/analysis_result_screen.dart';
import 'package:tatarai/features/payment/views/premium_screen.dart';

part 'analysis_screen_mixin.dart';

/// Bitki analizi ekranı
/// Fotoğraf çekme, yükleme ve yapay zeka analizini başlatma
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin, _AnalysisScreenMixin {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Bitki Analizi'),
        border: Border(
          bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: BlocConsumer<PlantAnalysisCubit, PlantAnalysisState>(
          listener: (context, state) async {
            if (state.status == AnalysisStatus.success &&
                state.selectedAnalysisResult != null) {
              // Analiz başarılı olduğunda sonuç ekranına geçiş
              final currentAnalysisId = state.selectedAnalysisResult?.id;

              // Eğer _lastNavigatedAnalysisId ile aynıysa, navigation yapma
              if (_lastNavigatedAnalysisId != currentAnalysisId) {
                _lastNavigatedAnalysisId = currentAnalysisId;

                final resultId = state.selectedAnalysisResult!.id;
                AppLogger.i(
                  'Analiz sonuç ekranına geçiş - ID: $resultId, Uzunluk: ${resultId.length}',
                );

                Navigator.of(context)
                    .push(
                  CupertinoPageRoute(
                    builder: (context) =>
                        AnalysisResultScreen(analysisId: resultId),
                  ),
                )
                    .then((_) {
                  // Sonuç ekranından dönüldüğünde state'i sıfırla
                  context.read<PlantAnalysisCubit>().reset();
                  // Navigation ID'sini temizle
                  _lastNavigatedAnalysisId = null;
                });
              }
            } else if (state.errorMessage != null) {
              // Hata durumunda kullanıcıya bilgi ver
              // needsPremium true ise premium satın alma sayfasına yönlendirme seçeneği sunan diyalog göster
              await _showErrorDialog(state.errorMessage!,
                  needsPremium: state.needsPremium);
            }
          },
          builder: (context, state) {
            final bool isAnalyzing = state.isLoading;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Başlık ve açıklama
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bitkiniz Hakkında Bilgi Alın',
                            style: AppTextTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bitkinin net bir fotoğrafını çekin veya yükleyin. Yapay zeka, hastalık durumunu ve öneriler sunacak.',
                            style: AppTextTheme.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Fotoğraf önizleme alanı
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _selectedImage != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Resim Hero animasyonu ile
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            context.dimensions.radiusL),
                                        child: Hero(
                                          tag: 'plantImage',
                                          child: Image.file(
                                            _selectedImage!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        ),
                                      ),
                                      // Resim üstündeki yarı saydam kontrol katmanı - Cupertino uyumlu
                                      GestureDetector(
                                        onTap: isAnalyzing
                                            ? null
                                            : _showImageOptionsMenu,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.center,
                                              colors: [
                                                CupertinoColors.black
                                                    .withOpacity(0.4),
                                                CupertinoColors.transparent,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                                context.dimensions.radiusL),
                                          ),
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                  bottom: context
                                                      .dimensions.paddingM),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: context
                                                      .dimensions.paddingM,
                                                  vertical: context
                                                      .dimensions.paddingXS,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: CupertinoColors.white
                                                      .withOpacity(0.8),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          context.dimensions
                                                              .radiusL),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: CupertinoColors
                                                          .black
                                                          .withOpacity(0.1),
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      CupertinoIcons
                                                          .camera_fill,
                                                      color: AppColors.primary,
                                                      size: context
                                                          .dimensions.iconSizeS,
                                                    ),
                                                    SizedBox(
                                                        width: context
                                                            .dimensions
                                                            .spaceXXS),
                                                    Text(
                                                      'Değiştir',
                                                      style: AppTextTheme
                                                          .captionL
                                                          .copyWith(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: CupertinoColors
                                                            .label,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Bilgi simgesi (sağ üst köşe)
                                      Positioned(
                                        top: context.dimensions.paddingS,
                                        right: context.dimensions.paddingS,
                                        child: Container(
                                          height:
                                              context.dimensions.buttonHeight *
                                                  0.7,
                                          width:
                                              context.dimensions.buttonHeight *
                                                  0.7,
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.white
                                                .withOpacity(0.8),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: CupertinoColors.black
                                                    .withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            CupertinoIcons.info,
                                            color: AppColors.primary,
                                            size: context.dimensions.iconSizeS,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : GestureDetector(
                                    onTap:
                                        isAnalyzing ? null : _showPhotoOptions,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemBackground,
                                        borderRadius: BorderRadius.circular(
                                            context.dimensions.radiusL),
                                        border: Border.all(
                                          color: CupertinoColors.systemGrey5,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: CupertinoColors.systemGrey5
                                                .withOpacity(0.5),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // İçerik
                                          Padding(
                                            padding: EdgeInsets.all(
                                                context.dimensions.paddingL),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                // İkon kısmı
                                                Container(
                                                  width: context.dimensions
                                                          .screenWidth *
                                                      0.25,
                                                  height: context.dimensions
                                                          .screenWidth *
                                                      0.25,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        AppColors.primary
                                                            .withOpacity(0.1),
                                                        AppColors.primary
                                                            .withOpacity(0.05),
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: AppColors.primary
                                                          .withOpacity(0.2),
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    CupertinoIcons.camera,
                                                    color: AppColors.primary,
                                                    size: context
                                                        .dimensions.iconSizeL,
                                                  ),
                                                ),
                                                SizedBox(
                                                    height: context
                                                        .dimensions.spaceM),
                                                Text(
                                                  'Fotoğraf Ekleyin',
                                                  style: AppTextTheme.bodyLarge
                                                      .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(
                                                    height: context
                                                        .dimensions.spaceXS),
                                                Text(
                                                  'Analizin doğru yapılabilmesi için bitkinizin net bir fotoğrafını ekleyin',
                                                  style: AppTextTheme.bodyText2
                                                      .copyWith(
                                                    color: CupertinoColors
                                                        .systemGrey,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Ekleme butonu (sağ alt köşede)
                                          Positioned(
                                            bottom: context.dimensions.paddingM,
                                            right: context.dimensions.paddingM,
                                            child: Container(
                                              height: context
                                                  .dimensions.buttonHeight,
                                              width: context
                                                  .dimensions.buttonHeight,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppColors.primary,
                                                    AppColors.primary
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.primary
                                                        .withOpacity(0.3),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                CupertinoIcons.plus,
                                                color: CupertinoColors.white,
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Konum seçimi (il, ilçe, mahalle)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konum Bilgileri',
                            style: AppTextTheme.captionL.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // İl seçimi
                          GestureDetector(
                            onTap: _showProvinceSelector,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey4,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.map_pin,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'İl',
                                          style: AppTextTheme.caption.copyWith(
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedProvince?.name ?? "İl seçin",
                                          style:
                                              AppTextTheme.bodyText2.copyWith(
                                            color: _selectedProvince == null
                                                ? CupertinoColors.systemGrey
                                                : CupertinoColors.label,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _loadingProvinces
                                      ? const CupertinoActivityIndicator()
                                      : const Icon(
                                          CupertinoIcons.chevron_down,
                                          color: CupertinoColors.systemGrey,
                                          size: 16,
                                        ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // İlçe seçimi
                          GestureDetector(
                            onTap: _showDistrictSelector,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey4,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.location,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'İlçe',
                                          style: AppTextTheme.caption.copyWith(
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedDistrict?.name ??
                                              "İlçe seçin",
                                          style:
                                              AppTextTheme.bodyText2.copyWith(
                                            color: _selectedDistrict == null
                                                ? CupertinoColors.systemGrey
                                                : CupertinoColors.label,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _loadingDistricts
                                      ? const CupertinoActivityIndicator()
                                      : const Icon(
                                          CupertinoIcons.chevron_down,
                                          color: CupertinoColors.systemGrey,
                                          size: 16,
                                        ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Mahalle seçimi
                          GestureDetector(
                            onTap: _showNeighborhoodSelector,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey4,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.location_solid,
                                    color: AppColors.info,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Mahalle',
                                          style: AppTextTheme.caption.copyWith(
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedNeighborhood?.name ??
                                              "Mahalle seçin",
                                          style:
                                              AppTextTheme.bodyText2.copyWith(
                                            color: _selectedNeighborhood == null
                                                ? CupertinoColors.systemGrey
                                                : CupertinoColors.label,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _loadingNeighborhoods
                                      ? const CupertinoActivityIndicator()
                                      : const Icon(
                                          CupertinoIcons.chevron_down,
                                          color: CupertinoColors.systemGrey,
                                          size: 16,
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tarla adı kısmı
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tarla Bilgileri',
                            style: AppTextTheme.captionL.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Tarla seçimi
                          GestureDetector(
                            onTap: _showFieldNameInput,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey4,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.tree,
                                    color: AppColors.success,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tarla Adı',
                                          style: AppTextTheme.caption.copyWith(
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _fieldNameController.text.isEmpty
                                              ? "Tarla adı girin"
                                              : _fieldNameController.text,
                                          style:
                                              AppTextTheme.bodyText2.copyWith(
                                            color: _fieldNameController
                                                    .text.isEmpty
                                                ? CupertinoColors.systemGrey
                                                : CupertinoColors.label,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    CupertinoIcons.chevron_down,
                                    color: CupertinoColors.systemGrey,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Analiz butonu
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: AppButton(
                        text: isAnalyzing ? 'Analiz Ediliyor...' : 'Analiz Et',
                        isLoading: isAnalyzing,
                        onPressed: _selectedImage != null && !isAnalyzing
                            ? _startAnalysis
                            : null,
                        icon: isAnalyzing
                            ? null
                            : CupertinoIcons.leaf_arrow_circlepath,
                        height: 58,
                      ),
                    ),

                    // İpuçları kartı
                    if (_selectedImage != null)
                      AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 500),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.info.withOpacity(0.1),
                                  AppColors.primary.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.info.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.info.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.lightbulb_fill,
                                        color: AppColors.info,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Analiz İpuçları',
                                      style: AppTextTheme.captionL.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.info,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.checkmark_circle_fill,
                                      color: AppColors.info,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Bitkinizin yaprak ve gövdesini net şekilde gösteren fotoğraflar kullanın',
                                        style: AppTextTheme.bodyText2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.checkmark_circle_fill,
                                      color: AppColors.info,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Gün ışığında veya iyi aydınlatma altında çekim yapın',
                                        style: AppTextTheme.bodyText2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.checkmark_circle_fill,
                                      color: AppColors.info,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Hastalık belirtileri varsa, bu bölgelere odaklanın',
                                        style: AppTextTheme.bodyText2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
