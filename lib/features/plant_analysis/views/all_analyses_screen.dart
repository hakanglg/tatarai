import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_cubit.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_state.dart';
import 'package:tatarai/features/plant_analysis/views/analysis_result_screen.dart';

/// Tüm analizleri gösteren ekran
class AllAnalysesScreen extends StatefulWidget {
  const AllAnalysesScreen({super.key});

  @override
  State<AllAnalysesScreen> createState() => _AllAnalysesScreenState();
}

class _AllAnalysesScreenState extends State<AllAnalysesScreen> {
  @override
  void initState() {
    super.initState();
    // Geçmiş analizleri yükle
    context.read<PlantAnalysisCubit>().loadPastAnalyses();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground,
        middle: Text('Tüm Analizler', style: TextStyle(color: Colors.black)),
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Icon(
            CupertinoIcons.back,
            color: Colors.black, // Ok simgesinin rengi burada
          ),
        ),
      ),
      child: SafeArea(
        child: BlocBuilder<PlantAnalysisCubit, PlantAnalysisState>(
          builder: (context, state) {
            // Yükleniyor durumu
            if (state.isLoading) {
              return const Center(
                child: CupertinoActivityIndicator(radius: 16),
              );
            }

            // Hata durumu
            if (state.errorMessage != null) {
              return Center(
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
                        state.errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTextTheme.bodyText2.copyWith(
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 160,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 24,
                        ),
                        color: AppColors.secondary,
                        child: const Text('Tekrar Dene'),
                        onPressed: () {
                          context.read<PlantAnalysisCubit>().loadPastAnalyses();
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            // Analiz yoksa boş durumu göster
            if (state.analysisList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.doc_text,
                        color: CupertinoColors.systemGrey,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Henüz Analiz Yok', style: AppTextTheme.headline5),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Tarla ve bitkiniz hakkında bilgi almak için bir analiz yapın',
                        textAlign: TextAlign.center,
                        style: AppTextTheme.bodyText2.copyWith(
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Tüm analizleri listele
            return ListView.builder(
              padding: const EdgeInsets.only(top: 12),
              itemCount: state.analysisList.length,
              itemBuilder: (context, index) {
                return _buildAnalysisItem(context, state.analysisList[index]);
              },
            );
          },
        ),
      ),
    );
  }

  // Analiz öğesi widget'ı
  Widget _buildAnalysisItem(
      BuildContext context, PlantAnalysisResult analysis) {
    // Tarih formatı, gerçekte Firestore'dan timestamp alacak şekilde düzenlenmeli
    final DateTime createdAt = DateTime.now();
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
                            AppLogger.e('Resim yüklenirken hata', error);
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
                    Text(
                      formattedDate,
                      style: AppTextTheme.caption,
                    ),
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
}
