import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_cubit.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_state.dart';
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
    return Scaffold(
      body: CupertinoPageScaffold(
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
              if (state.isLoading) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.hourglass,
                        size: context.dimensions.iconSizeXL,
                      ),
                      SizedBox(height: context.dimensions.spaceM),
                      Text('Analizler yükleniyor...'),
                      SizedBox(height: context.dimensions.spaceXS),
                      Text('Lütfen bekleyin...'),
                      SizedBox(height: context.dimensions.spaceL),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: context.dimensions.paddingL),
                        child: CupertinoActivityIndicator(),
                      ),
                    ],
                  ),
                );
              }

              if (state.errorMessage != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_circle,
                        size: context.dimensions.iconSizeXL,
                      ),
                      SizedBox(height: context.dimensions.spaceM),
                      Text('Bir hata oluştu'),
                      SizedBox(height: context.dimensions.spaceXS),
                      Text(state.errorMessage!),
                      SizedBox(height: context.dimensions.spaceL),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: context.dimensions.paddingL),
                        child: CupertinoButton(
                          onPressed: () {
                            context
                                .read<PlantAnalysisCubit>()
                                .loadPastAnalyses();
                          },
                          child: Text('Tekrar Dene'),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (state.analysisList.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: context.dimensions.paddingM),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(context.dimensions.paddingM),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(
                                context.dimensions.radiusM),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Henüz hiç analiz yapmadınız',
                                style: TextStyle(
                                  fontSize: context.dimensions.fontSizeL,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: context.dimensions.spaceXS),
                              Text(
                                'Bitki analizi yapmak için ana sayfaya dönün',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: context.dimensions.fontSizeM,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.only(top: context.dimensions.paddingM),
                itemCount: state.analysisList.length,
                itemBuilder: (context, index) {
                  return AnalysisListItem(
                    analysis: state.analysisList[index],
                    onTap: () => _showAnalysisDetails(
                        context, state.analysisList[index]),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAnalysisDetails(
      BuildContext context, PlantAnalysisResult analysis) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => AnalysisResultScreen(analysisId: analysis.id),
      ),
    );
  }
}

class AnalysisListItem extends StatelessWidget {
  final PlantAnalysisResult analysis;
  final VoidCallback onTap;

  const AnalysisListItem({
    super.key,
    required this.analysis,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.dimensions.paddingM,
        vertical: context.dimensions.paddingXS,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: EdgeInsets.all(context.dimensions.paddingM),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(context.dimensions.radiusS),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withOpacity(0.1),
                blurRadius: context.dimensions.radiusXS,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(context.dimensions.radiusS),
                child: Image.network(
                  analysis.imageUrl,
                  width: context.dimensions.buttonHeight * 1.5,
                  height: context.dimensions.buttonHeight * 1.5,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: context.dimensions.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      analysis.fieldName != null &&
                              analysis.fieldName!.isNotEmpty
                          ? analysis.fieldName!
                          : analysis.plantName,
                      style: TextStyle(
                        fontSize: context.dimensions.fontSizeM,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: context.dimensions.spaceXXS),
                    Text(
                      analysis.plantName,
                      style: TextStyle(
                        fontSize: context.dimensions.fontSizeS,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey,
                size: context.dimensions.iconSizeS,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
