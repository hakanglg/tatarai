import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sprung/sprung.dart';
import 'package:tatarai/core/utils/permission_manager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/extensions/string_extension.dart';
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
import 'package:tatarai/core/extensions/context_extensions.dart';
import 'package:tatarai/features/profile/cubits/profile_cubit.dart';

part 'analysis_screen_mixin.dart';

/// Bitki analizi ekranı
/// Fotoğraf çekme, yükleme ve yapay zeka analizini başlatma
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with _AnalysisScreenMixin, TickerProviderStateMixin {
  @override
  void initState() {
    AppLogger.i('AnalysisScreen - initState başladı');
    super.initState();

    try {
      _initializeAnimations();
      _checkEmulator();
      _loadProvinces();
      AppLogger.i('AnalysisScreen - initState tamamlandı');
    } catch (e) {
      AppLogger.e('AnalysisScreen - initState hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.i('AnalysisScreen - build başladı');
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.background,
        middle: Text('plant_analysis'.locale(context)),
        border: const Border(
          bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: BlocConsumer<PlantAnalysisCubit, PlantAnalysisState>(
          listener: (context, state) async {
            AppLogger.i(
                'AnalysisScreen - BlocConsumer listener tetiklendi: ${state.status}');
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

                // Sadece mounted durumunu kontrol et, canPop kontrolünü kaldır
                if (mounted) {
                  await Navigator.of(context)
                      .push(
                    CupertinoPageRoute(
                      builder: (context) =>
                          AnalysisResultScreen(analysisId: resultId),
                    ),
                  )
                      .then((_) {
                    // Sonuç ekranından dönüldüğünde state'i sıfırla
                    if (mounted) {
                      context.read<PlantAnalysisCubit>().reset();
                      // Navigation ID'sini temizle
                      _lastNavigatedAnalysisId = null;
                    }
                  });
                }
              }
            } else if (state.errorMessage != null) {
              // Hata durumunda kullanıcıya bilgi ver
              // needsPremium true ise premium satın alma sayfasına yönlendirme seçeneği sunan diyalog göster
              await _showErrorDialog(state.errorMessage!,
                  needsPremium: state.needsPremium);
            }
          },
          builder: (context, state) {
            AppLogger.i(
                'AnalysisScreen - BlocConsumer builder tetiklendi: ${state.status}');
            final bool isAnalyzing = state.isLoading;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  AppLogger.i('AnalysisScreen - AnimatedBuilder tetiklendi');
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
                            'plant_analysis_title'.locale(context),
                            style: AppTextTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'plant_analysis_desc'.locale(context),
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
                                                      'change_photo'
                                                          .locale(context),
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
                                    onTap: isAnalyzing
                                        ? null
                                        : _showPhotoSourceDialog,
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
                                                  'add_photo'.locale(context),
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
                            'location_info'.locale(context),
                            style: AppTextTheme.captionL.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // İl seçimi
                          GestureDetector(
                            onTap: _showProvinceSelection,
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
                                          'province'.locale(context),
                                          style: AppTextTheme.caption.copyWith(
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedProvince?.name ??
                                              'select_province'.locale(context),
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
                            onTap: _showDistrictSelection,
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
                                          'district'.locale(context),
                                          style: AppTextTheme.caption.copyWith(
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedDistrict?.name ??
                                              'select_district'.locale(context),
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
                            onTap: _showNeighborhoodSelection,
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
                                          'neighborhood'.locale(context),
                                          style: AppTextTheme.caption.copyWith(
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedNeighborhood?.name ??
                                              'select_neighborhood'
                                                  .locale(context),
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
                            'field_info'.locale(context),
                            style: AppTextTheme.captionL.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Tarla seçimi
                          GestureDetector(
                            onTap: _showFieldNameDialog,
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
                                          'field_name'.locale(context),
                                          style: AppTextTheme.caption.copyWith(
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _fieldNameController.text.isEmpty
                                              ? 'field_name'.locale(context)
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
                        text: isAnalyzing
                            ? 'analyzing'.locale(context)
                            : 'analyze'.locale(context),
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
                                      'analysis_tips'.locale(context),
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
                                        'tip_clear_photo'.locale(context),
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
                                        'tip_good_lighting'.locale(context),
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
                                        'tip_focus_disease'.locale(context),
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
