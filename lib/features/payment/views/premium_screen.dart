import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/models/auth_state.dart';

/// Premium yükseltme ekranı
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isLoading = true;
  bool _isPurchasePending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initInAppPurchase();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  /// In-App Purchase'ı başlat
  Future<void> _initInAppPurchase() async {
    try {
      final bool available = await _inAppPurchase.isAvailable();

      if (!available) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Uygulama içi satın alma kullanılamıyor.';
        });
        return;
      }

      // Satın alma güncellemelerini dinle
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription.cancel(),
        onError: (error) {
          AppLogger.e('Satın alma hatası', error);
          setState(() {
            _isPurchasePending = false;
            _errorMessage = 'Satın alma sırasında bir hata oluştu.';
          });
        },
      );

      // Abonelik ürünlerini yükle
      await _loadProducts();
    } catch (e) {
      AppLogger.e('In-app purchase başlatma hatası', e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ödeme sistemi başlatılamadı.';
      });
    }
  }

  /// Ürünleri yükle
  Future<void> _loadProducts() async {
    try {
      final Set<String> productIds = <String>{
        AppConstants.subscriptionMonthlyId,
        AppConstants.subscriptionYearlyId,
      };

      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(productIds);

      if (response.notFoundIDs.isNotEmpty) {
        AppLogger.w('Bulunamayan ürün IDs: ${response.notFoundIDs}');
      }

      setState(() {
        _products = response.productDetails;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.e('Ürün yükleme hatası', e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Abonelik bilgileri yüklenemedi.';
      });
    }
  }

  /// Satın alma güncellemelerini işle
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        setState(() {
          _isPurchasePending = true;
        });
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        setState(() {
          _isPurchasePending = false;
          _errorMessage = 'Satın alma işlemi sırasında bir hata oluştu.';
        });
        _handlePurchaseError(purchaseDetails.error!);
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        _handleSuccessfulPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        setState(() {
          _isPurchasePending = false;
        });
      }

      // Eğer satın alma işlemi tamamlandıysa, işlem bilgilerini doğrula ve onayla
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// Başarılı satın alma işlemleri
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    try {
      // Abonelik tipini belirle
      final bool isMonthly =
          purchase.productID == AppConstants.subscriptionMonthlyId;
      final String subscriptionType = isMonthly ? 'aylık' : 'yıllık';

      AppLogger.i('Başarılı satın alma: $subscriptionType abonelik');

      // Kullanıcı modelini güncelle
      await context.read<AuthCubit>().upgradeToPremium();

      setState(() {
        _isPurchasePending = false;
      });

      // Kullanıcıya başarı mesajı göster
      _showSuccessDialog(subscriptionType);
    } catch (e) {
      AppLogger.e('Premium yükseltme hatası', e);
      setState(() {
        _isPurchasePending = false;
        _errorMessage = 'Premium yükseltme sırasında bir hata oluştu.';
      });
    }
  }

  /// Satın alma hatalarını işle
  void _handlePurchaseError(IAPError error) {
    AppLogger.e('Satın alma hatası: ${error.code} - ${error.message}', error);
    setState(() {
      _isPurchasePending = false;
      _errorMessage =
          'Satın alma işlemi sırasında bir hata oluştu: ${error.message}';
    });
  }

  /// Satın alma işlemini başlat
  Future<void> _buyProduct(ProductDetails product) async {
    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: null,
      );

      if (Platform.isAndroid) {
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else if (Platform.isIOS) {
        await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      AppLogger.e('Satın alma başlatma hatası', e);
      setState(() {
        _isPurchasePending = false;
        _errorMessage = 'Satın alma başlatılamadı.';
      });
    }
  }

  /// Başarılı satın alma diyaloğu
  void _showSuccessDialog(String subscriptionType) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Premium Üyelik Aktif'),
          content: Text(
            'Tebrikler! $subscriptionType premium üyeliğiniz başarıyla aktifleştirildi. '
            'Artık TatarAI\'nin tüm premium özelliklerine erişebilirsiniz.',
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              child: const Text('Tamam'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Premium ekranını kapat
              },
            ),
          ],
        );
      },
    );
  }

  /// Fiyat bilgisini formatla
  String _formatPrice(ProductDetails product) {
    return '${product.price} / ${product.id == AppConstants.subscriptionMonthlyId ? 'Ay' : 'Yıl'}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state.user;
        final bool isPremium = user?.isPremium ?? false;
        final size = MediaQuery.of(context).size;

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Premium\'a Yükselt'),
            backgroundColor: CupertinoColors.systemBackground,
            brightness: Brightness.light,
            border: const Border(bottom: BorderSide(color: Colors.transparent)),
            previousPageTitle: ' ',
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(
                CupertinoIcons.back,
                color: CupertinoColors.black,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          backgroundColor: CupertinoColors.systemBackground,
          child: SafeArea(
            child:
                isPremium
                    ? _buildPremiumActiveContent()
                    : _buildSingleScreenContent(size, isPremium),
          ),
        );
      },
    );
  }

  /// Premium aktif olan kullanıcılar için içerik
  Widget _buildPremiumActiveContent() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 60,
              color: CupertinoColors.white,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Premium Üyeliğiniz Aktif',
            style: AppTextTheme.headline3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'TatarAI\'nin tüm premium özelliklerine erişiminiz var.',
            textAlign: TextAlign.center,
            style: AppTextTheme.subtitle1,
          ),
          const SizedBox(height: 48),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActiveFeatureItem(
                  'Sınırsız bitki analizi yapabilirsiniz',
                ),
                _buildActiveFeatureItem('Detaylı raporlara erişebilirsiniz'),
                _buildActiveFeatureItem(
                  'Özel içeriklerden faydalanabilirsiniz',
                ),
                _buildActiveFeatureItem('Öncelikli destek alabilirsiniz'),
              ],
            ),
          ),
          AppButton(
            text: 'Anasayfaya Dön',
            height: 50,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Premium aktif olan kullanıcılar için özellik item'ı
  Widget _buildActiveFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.checkmark_alt,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: AppTextTheme.subtitle1)),
        ],
      ),
    );
  }

  /// Tek ekranda premium içerik
  Widget _buildSingleScreenContent(Size size, bool isPremium) {
    // Ekran boyutlarına göre uyarla
    final bool isSmallScreen = size.height < 700;

    return Container(
      height: size.height,
      width: size.width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            CupertinoColors.systemBackground,
            AppColors.primary.withOpacity(0.07),
            AppColors.secondary.withOpacity(0.05),
          ],
          stops: const [0.5, 0.8, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Üst Bölüm - Logo ve Başlık
          Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Arka plan efekti
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Orta halka
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.4),
                          AppColors.secondary.withOpacity(0.4),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Ana ikon
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                        // İkinci gölge efekti
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(-3, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.star_fill,
                        size: 40,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                  // "Premium" etiketi
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            CupertinoIcons.sparkles,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'PREMIUM',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.sparkles,
                            color: Colors.white,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Üst Seviye Tarım Teknolojisi',
                style: AppTextTheme.headline5,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 30),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Premium ile tarımda %67 daha yüksek verimlilik sağlayın',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),

          // Orta Bölüm - Özellikler
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: isSmallScreen ? 8 : 16,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildEnhancedFeature(
                    icon: CupertinoIcons.infinite,
                    title: 'Sınırsız Analiz',
                    subtitle:
                        'Normal kullanıcılar ay başına 5 analiz yapabilir',
                    highlightColor: CupertinoColors.systemIndigo,
                  ),
                  _buildEnhancedFeature(
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    title: 'Detaylı Hastalık Tespiti',
                    subtitle: 'Olası tüm hastalık tiplerini %96 doğrulukla gör',
                    highlightColor: CupertinoColors.systemGreen,
                  ),
                  _buildEnhancedFeature(
                    icon: CupertinoIcons.bolt_fill,
                    title: 'Öncelikli İşleme',
                    subtitle: 'Analizleriniz premium kuyruğunda hızla işlenir',
                    highlightColor: CupertinoColors.systemOrange,
                  ),
                  _buildEnhancedFeature(
                    icon: CupertinoIcons.arrow_down_doc_fill,
                    title: 'Raporları İndir',
                    subtitle: 'Tüm analizleri PDF olarak kaydedebilirsiniz',
                    highlightColor: CupertinoColors.systemBlue,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),

          // Alt Bölüm - Fiyatlandırma
          if (!_isLoading && _errorMessage == null && !isPremium)
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                children: [
                  // Sınırlı Süre Uyarısı
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.secondary, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.2),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.clock_fill,
                          color: AppColors.secondary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Sınırlı Süre Fırsatı: %25 İndirim',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Bu teklif 48 saat içinde sona erecek',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Planlar
                  if (_products.isNotEmpty)
                    Row(
                      children:
                          _products.map((product) {
                            final bool isYearly =
                                product.id == AppConstants.subscriptionYearlyId;
                            return Expanded(
                              child: GestureDetector(
                                onTap:
                                    _isPurchasePending
                                        ? null
                                        : () => _buyProduct(product),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Ürün kartı
                                    Container(
                                      margin: EdgeInsets.only(
                                        left: isYearly ? 8 : 0,
                                        right: isYearly ? 0 : 8,
                                        top:
                                            isYearly
                                                ? 0
                                                : 12, // Yıllık planı biraz daha yukarıda göster
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color:
                                            isYearly
                                                ? AppColors.primary.withOpacity(
                                                  0.1,
                                                )
                                                : CupertinoColors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color:
                                              isYearly
                                                  ? AppColors.primary
                                                  : CupertinoColors.systemGrey5,
                                          width: isYearly ? 2 : 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                isYearly
                                                    ? AppColors.primary
                                                        .withOpacity(0.15)
                                                    : CupertinoColors
                                                        .systemGrey6
                                                        .withOpacity(0.5),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          // Eğer popüler plan ise (yıllık), bir rozet ekle
                                          if (isYearly)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    AppColors.primary,
                                                    AppColors.secondary,
                                                  ],
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'EN POPÜLER',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            isYearly ? 'Yıllık' : 'Aylık',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  isYearly
                                                      ? AppColors.primary
                                                      : CupertinoColors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Eski fiyat (üzeri çizili) - sadece yıllık plan için göster
                                              if (isYearly)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 6,
                                                        top: 3,
                                                      ),
                                                  child: Text(
                                                    '${(double.parse(product.price.replaceAll(RegExp(r'[^0-9.,]'), '')) * 1.25).toStringAsFixed(2)} TL',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          CupertinoColors
                                                              .systemGrey,
                                                      decoration:
                                                          TextDecoration
                                                              .lineThrough,
                                                      decorationColor:
                                                          CupertinoColors
                                                              .systemGrey,
                                                      decorationThickness: 2,
                                                    ),
                                                  ),
                                                ),
                                              // Ana fiyat
                                              Text(
                                                product.price.split('.').first,
                                                style: TextStyle(
                                                  fontSize: isYearly ? 24 : 20,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      isYearly
                                                          ? AppColors.primary
                                                          : Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                product.price.contains('.')
                                                    ? ',${product.price.split('.')[1].substring(0, 2)}'
                                                    : '',
                                                style: TextStyle(
                                                  fontSize: isYearly ? 18 : 16,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      isYearly
                                                          ? AppColors.primary
                                                          : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            isYearly ? 'yıl' : 'ay',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color:
                                                  isYearly
                                                      ? AppColors.primary
                                                          .withOpacity(0.7)
                                                      : CupertinoColors
                                                          .systemGrey,
                                            ),
                                          ),
                                          if (isYearly)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.secondary
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                '2 AY BEDAVA',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.secondary,
                                                ),
                                              ),
                                            ),
                                          if (isYearly)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                top: 10,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: CupertinoColors
                                                    .systemGreen
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    CupertinoIcons
                                                        .money_dollar_circle_fill,
                                                    size: 14,
                                                    color:
                                                        CupertinoColors
                                                            .systemGreen,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    '%25 indirim + %16 tasarruf',
                                                    style: TextStyle(
                                                      color:
                                                          CupertinoColors
                                                              .systemGreen,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Parıltı efekti (sadece yıllık planda göster)
                                    if (isYearly)
                                      Positioned(
                                        top: -5,
                                        right: -5,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: AppColors.secondary
                                                .withOpacity(0.9),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.secondary
                                                    .withOpacity(0.5),
                                                blurRadius: 10,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              CupertinoIcons.sparkles,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),

                  // Satın Alma Butonu
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: AppButton(
                      text:
                          _isPurchasePending
                              ? 'İşleniyor...'
                              : 'HEMEN PREMİUM\'A YÜKSELT',
                      type: AppButtonType.primary,
                      isLoading: _isPurchasePending,
                      height: 54, // Biraz daha yüksek
                      onPressed:
                          _isPurchasePending || _products.isEmpty
                              ? null
                              : () => _buyProduct(
                                _products.firstWhere(
                                  (product) =>
                                      product.id ==
                                      AppConstants.subscriptionYearlyId,
                                  orElse: () => _products.first,
                                ),
                              ),
                    ),
                  ),

                  // Garanti ve güven metni
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        CupertinoIcons.shield_fill,
                        color: CupertinoColors.systemGreen,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '7 gün içinde koşulsuz iade garantisi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          if (_isLoading && !isPremium)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: const [
                  CupertinoActivityIndicator(radius: 14),
                  SizedBox(height: 16),
                  Text(
                    'Size özel fiyat teklifi hazırlanıyor...',
                    style: TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          if (_errorMessage != null && !isPremium)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_circle,
                    color: CupertinoColors.systemRed,
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: CupertinoColors.systemGrey),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: 'Tekrar Dene',
                    type: AppButtonType.secondary,
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      _initInAppPurchase();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Geliştirilmiş özellik gösterimi
  Widget _buildEnhancedFeature({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color highlightColor,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // İkon konteyneri - renk varyasyonları ile
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      highlightColor.withOpacity(0.8),
                      highlightColor.withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: highlightColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: highlightColor.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(-2, 2),
                    ),
                  ],
                ),
                child: Center(child: Icon(icon, color: Colors.white, size: 26)),
              ),
              const SizedBox(width: 16),
              // Metin içeriği
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Onay işareti - animasyon hissi verecek tasarım
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.7),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.checkmark,
                    size: 14,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Ayırıcı çizgi (son eleman değilse)
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Divider(
              color: CupertinoColors.systemGrey5.withOpacity(0.5),
              height: 1,
            ),
          ),
      ],
    );
  }
}

/// Premium özellik widgetı
class _PremiumFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PremiumFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey6.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextTheme.subtitle1.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
        ],
      ),
    );
  }
}
