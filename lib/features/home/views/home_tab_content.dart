import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/models/auth_state.dart';
import 'package:tatarai/features/navbar/navigation_manager.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_cubit.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_state.dart';
import 'package:tatarai/features/plant_analysis/views/analysis_result_screen.dart';
import 'package:tatarai/features/plant_analysis/views/all_analyses_screen.dart';

/// Ana ekran tab içeriği - Karşılama ekranı ve hızlı erişim seçenekleri
class HomeTabContent extends StatefulWidget {
  const HomeTabContent({super.key});

  @override
  State<HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<HomeTabContent> {
  @override
  void initState() {
    super.initState();

    // Geçmiş analizleri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlantAnalysisCubit>().loadPastAnalyses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state.user;
        final userName =
            user?.displayName ?? user?.email.split('@').first ?? 'Çiftçi';

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(AppConstants.appName),
            // iOS stil navigation bar
            backgroundColor: CupertinoColors.systemBackground,
            brightness: Brightness.light,
            border: Border(
              bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
            ),
            padding: EdgeInsetsDirectional.zero,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Karşılama başlığı
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Merhaba, $userName',
                          style: AppTextTheme.headline2,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bitki sağlığını yapay zeka ile analiz etmeye hazır mısın?',
                          style: AppTextTheme.bodyText1.copyWith(
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Hızlı başlangıç kartı
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              const Icon(
                                CupertinoIcons.camera_fill,
                                color: AppColors.primary,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Hızlı Analiz',
                                      style: AppTextTheme.headline5,
                                    ),
                                    Text(
                                      'Bitkinin fotoğrafını çekerek analizini başlat',
                                      style: AppTextTheme.bodyText2.copyWith(
                                        color: CupertinoColors.systemGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              text: 'Fotoğraf Çek',
                              onPressed: () {
                                try {
                                  // NavigationManager üzerinden sekmeyi değiştir
                                  final navManager =
                                      Provider.of<NavigationManager>(
                                    context,
                                    listen: false,
                                  );
                                  navManager.switchToTab(
                                    1,
                                  ); // Analiz sekmesine geç
                                } catch (e, stack) {
                                  AppLogger.e(
                                    'Tab geçişi yapılamadı',
                                    e,
                                    stack,
                                  );
                                }
                              },
                              height: 44,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Son analizler başlığı
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Son Analizler',
                          style: AppTextTheme.headline5,
                        ),
                        SizedBox(
                          height: 32,
                          child: AppButton(
                            text: 'Tümünü Gör',
                            type: AppButtonType.text,
                            height: 32,
                            isFullWidth: false,
                            onPressed: () {
                              // Tüm analizleri görüntüleme ekranına geçiş yapılacak
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (context) =>
                                      const AllAnalysesScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Son analizler listesi - Gerçek verilerle
                  BlocBuilder<PlantAnalysisCubit, PlantAnalysisState>(
                    builder: (context, state) {
                      // Yükleniyor durumu
                      if (state.isLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CupertinoActivityIndicator(),
                          ),
                        );
                      }

                      // Hata durumu
                      if (state.errorMessage != null) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(
                                  CupertinoIcons.exclamationmark_circle,
                                  color: CupertinoColors.systemRed,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Analizler yüklenirken hata oluştu',
                                  style: AppTextTheme.subtitle1,
                                ),
                                const SizedBox(height: 8),
                                AppButton(
                                  text: 'Tekrar Dene',
                                  type: AppButtonType.secondary,
                                  onPressed: () {
                                    context
                                        .read<PlantAnalysisCubit>()
                                        .loadPastAnalyses();
                                  },
                                  isFullWidth: false,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Veri yok durumu
                      if (state.analysisList.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                const Icon(
                                  CupertinoIcons.doc,
                                  color: CupertinoColors.systemGrey,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Henüz analiz yapılmamış',
                                  style: AppTextTheme.subtitle1,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Hemen ilk analizini yap!',
                                  style: AppTextTheme.bodyText2.copyWith(
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                AppButton(
                                  text: 'Analiz Yap',
                                  type: AppButtonType.secondary,
                                  onPressed: () {
                                    final navManager =
                                        Provider.of<NavigationManager>(
                                      context,
                                      listen: false,
                                    );
                                    navManager.switchToTab(1);
                                  },
                                  isFullWidth: false,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Analizleri göster - en fazla 3 tane
                      final analyses = state.analysisList;
                      final displayCount =
                          analyses.length > 3 ? 3 : analyses.length;

                      return Column(
                        children: List.generate(
                          displayCount,
                          (index) =>
                              _buildAnalysisItem(context, analyses[index]),
                        ),
                      );
                    },
                  ),

                  // Bilgi kartları başlığı
                  const Padding(
                    padding: EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 16.0,
                      bottom: 8.0,
                    ),
                    child: Text(
                      'Bilginizi Artırın',
                      style: AppTextTheme.headline5,
                    ),
                  ),

                  // Bilgi kartları
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildInfoCard(
                      context,
                      'Bitki Hastalıkları',
                      'Yaygın bitki hastalıkları ve tedavi yöntemleri hakkında bilgi edinin.',
                      CupertinoIcons.book_fill,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildInfoCard(
                      context,
                      'Optimum Sulama',
                      'Bitki türlerine göre en uygun sulama teknikleri.',
                      CupertinoIcons.drop_fill,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Analiz öğesi widget'ı - gerçek veriler için güncellenmiş
  Widget _buildAnalysisItem(
    BuildContext context,
    PlantAnalysisResult analysis,
  ) {
    // Tarih formatı, eğer analizde tarih bilgisi yok ise şu anki zamanı kullan
    final DateTime createdAt =
        DateTime.now(); // Örnek değer, gerçek uygulamada Firestore'dan gelecek
    final String formattedDate =
        '${createdAt.day} ${_getMonthName(createdAt.month)} ${createdAt.year}';

    // Durum rengi
    final Color statusColor = analysis.isHealthy
        ? CupertinoColors.systemGreen
        : analysis.diseases.isEmpty
            ? CupertinoColors.systemGrey
            : analysis.diseases.any((d) => d.probability > 0.7)
                ? CupertinoColors.systemRed
                : CupertinoColors.systemYellow;

    // Durum metni
    final String statusText = analysis.isHealthy
        ? 'Sağlıklı'
        : analysis.diseases.isEmpty
            ? 'Bilinmiyor'
            : analysis.diseases.any((d) => d.probability > 0.7)
                ? 'Ciddi Hastalık'
                : 'Hafif Hastalık';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: GestureDetector(
        onTap: () {
          // Analiz detayı ekranına git
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) =>
                  AnalysisResultScreen(analysisId: analysis.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey6.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: analysis.imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          analysis.imageUrl,
                          fit: BoxFit.cover,
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                CupertinoIcons.photo,
                                color: CupertinoColors.systemGrey,
                              ),
                            );
                          },
                        ),
                      )
                    : const Center(
                        child: Icon(
                          CupertinoIcons.photo,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tarla adını title olarak göster, yoksa bitki adını kullan
                    Text(
                      analysis.fieldName != null &&
                              analysis.fieldName!.isNotEmpty
                          ? analysis.fieldName!
                          : analysis.plantName,
                      style: AppTextTheme.headline6,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Bitki adını subtitle olarak göster
                    Text(
                      analysis.plantName,
                      style: AppTextTheme.bodyText2.copyWith(
                        color: CupertinoColors.systemGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Analiz tarihi
                    Text(formattedDate, style: AppTextTheme.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: AppTextTheme.subtitle2.copyWith(color: statusColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Ay adını döndüren yardımcı metot
  String _getMonthName(int month) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return months[month - 1];
  }

  // Bilgi kartı widget'ı (değişmedi)
  Widget _buildInfoCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey6.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(icon, color: AppColors.secondary, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextTheme.headline6),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextTheme.bodyText2.copyWith(
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            CupertinoIcons.chevron_right,
            color: CupertinoColors.systemGrey,
          ),
        ],
      ),
    );
  }
}
