import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';

/// Premium yükseltme ekranı
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with SingleTickerProviderStateMixin {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isLoading = true;
  bool _isPurchasePending = false;
  String? _errorMessage;
  bool _isYearly = true; // Varsayılan olarak yıllık abonelik seçili
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initInAppPurchase();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// Animasyonları ayarla
  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(
      begin: 50,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
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

      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(productIds);

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
    final isPremium =
        context.select((AuthCubit cubit) => cubit.state.isPremium);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Premium',
            style: TextStyle(fontWeight: FontWeight.bold)),
        border: const Border(
          bottom: BorderSide(color: Colors.transparent),
        ),
        backgroundColor: Colors.transparent,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: SafeArea(
          bottom: false,
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return Stack(
                children: [
                  // Arka plan efekti
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _fadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value * 0.6,
                          child: Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(
                                    'assets/images/premium_bg_pattern.png'),
                                fit: BoxFit.cover,
                                opacity: 0.05,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Ana içerik
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Üst kısım - Premium başlık
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: AnimatedBuilder(
                              animation: _slideAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, _slideAnimation.value),
                                  child: child,
                                );
                              },
                              child: _buildPremiumHeader(isPremium),
                            ),
                          ),
                        ),
                      ),

                      // Premium özellikleri
                      SliverToBoxAdapter(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Premium Avantajları',
                                  style: AppTextTheme.headline4.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ..._buildFeatureList(),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Abonelik seçenekleri
                      if (!isPremium)
                        SliverToBoxAdapter(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                child: _isLoading
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32),
                                          child: CupertinoActivityIndicator(),
                                        ),
                                      )
                                    : _products.isEmpty
                                        ? _buildErrorState()
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildSubscriptionOptions(),
                                              const SizedBox(height: 32),
                                              _buildPurchaseButton(),
                                            ],
                                          ),
                              ),
                            ),
                          ),
                        ),

                      // Boşluk ekle
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],
                  ),

                  // Hata mesajı
                  if (_errorMessage != null) _buildErrorNotification(),

                  // Yükleniyor göstergesi
                  if (_isPurchasePending) _buildLoadingOverlay(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Premium başlığını oluştur
  Widget _buildPremiumHeader(bool isPremium) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.05),
            AppColors.primary.withOpacity(0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium ikonu
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      Color(0xFF00796B), // Daha koyu yeşil ton
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.star_circle_fill,
                    color: AppColors.white,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Premium başlık ve açıklama
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium ? 'Premium Aktif' : 'TatarAI Premium',
                      style: AppTextTheme.headline3.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPremium
                          ? 'Tüm premium özelliklere erişiminiz var.'
                          : 'TatarAI\'nin tüm potansiyelini keşfedin',
                      style: AppTextTheme.body.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Premium aktif mesajı
          if (isPremium) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      color: AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium Üyelik Aktif',
                          style: AppTextTheme.headline5.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tüm premium özelliklere sınırsız erişiminiz bulunuyor.',
                          style: AppTextTheme.captionL.copyWith(
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Premium değilse premium özet bilgisi
          if (!isPremium) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.rocket_fill,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tarım teknolojisinde çığır açın',
                          style: AppTextTheme.headline5.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPremiumSummaryItem(
                          icon: CupertinoIcons.infinite,
                          title: 'Sınırsız',
                          subtitle: 'Bitki analizi',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPremiumSummaryItem(
                          icon: CupertinoIcons.bolt_fill,
                          title: 'Öncelikli',
                          subtitle: 'Destek hizmeti',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPremiumSummaryItem(
                          icon: CupertinoIcons.chart_bar_alt_fill,
                          title: 'Gelişmiş',
                          subtitle: 'Hastalık teşhisi',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Premium özet öğesi
  Widget _buildPremiumSummaryItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: AppTextTheme.headline5.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTextTheme.captionL.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureItem(_FeatureItem feature) {
    return Container(
      margin: EdgeInsets.only(bottom: context.dimensions.spaceM),
      padding: EdgeInsets.all(context.dimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Özellik ikonu
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: feature.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(
                feature.icon,
                color: feature.color,
                size: 28,
              ),
            ),
          ),
          SizedBox(width: context.dimensions.spaceM),

          // Özellik bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: AppTextTheme.headline5.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: context.dimensions.spaceXXS),
                Text(
                  feature.description,
                  style: AppTextTheme.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          // Onay işareti
          const Icon(
            CupertinoIcons.checkmark_circle_fill,
            color: AppColors.success,
            size: 24,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeatureList() {
    final features = [
      _FeatureItem(
        title: 'Sınırsız Bitki Analizi',
        description: 'Her gün dilediğiniz kadar bitki analizi yapabilirsiniz',
        icon: CupertinoIcons.infinite,
        color: AppColors.primary,
      ),
      _FeatureItem(
        title: 'Öncelikli İşlem',
        description:
            'Analizleriniz öncelikli olarak işlenir, daha kısa sürede sonuç alırsınız',
        icon: CupertinoIcons.timer,
        color: AppColors.info,
      ),
      _FeatureItem(
        title: 'Detaylı Hastalık Teşhisi',
        description:
            'Yapay zeka destekli ileri düzey hastalık teşhisi ve tedavi önerileri',
        icon: CupertinoIcons.doc_text_search,
        color: AppColors.success,
      ),
      _FeatureItem(
        title: 'Sınırsız Geçmiş Erişimi',
        description: 'Tüm analiz geçmişinize ve sonuçlarınıza sınırsız erişim',
        icon: CupertinoIcons.chart_bar_alt_fill,
        color: AppColors.warning,
      ),
      _FeatureItem(
        title: 'Reklamsız Deneyim',
        description: 'Kesintisiz ve reklamsız premium kullanıcı deneyimi',
        icon: CupertinoIcons.eye,
        color: const Color(0xFF9C27B0), // Mor renk
      ),
    ];

    return features.map((feature) {
      return _buildFeatureItem(feature);
    }).toList();
  }

  Widget _buildSubscriptionOptions() {
    // Eğer ürünler yüklenemediyse varsayılan değerleri göster
    final bool hasProducts = _products.isNotEmpty;

    // Ürünleri bul veya varsayılan değerleri kullan
    final String monthlyPrice = hasProducts
        ? _findProductPrice(AppConstants.subscriptionMonthlyId)
        : AppConstants.defaultMonthlyPrice;
    final String yearlyPrice = hasProducts
        ? _findProductPrice(AppConstants.subscriptionYearlyId)
        : AppConstants.defaultYearlyPrice;

    // Yıllık fiyatın aylık karşılığını hesapla
    final String yearlyMonthlyPrice = hasProducts
        ? _calculateMonthlyPrice(AppConstants.subscriptionYearlyId)
        : AppConstants.defaultMonthlyOfYearlyPrice;

    // Yıllık abone olunduğunda tasarruf oranı
    final double savingsPercentage = AppConstants.savingsPercentage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        Text(
          'Abonelik Seçenekleri',
          style: AppTextTheme.headline4.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),

        // Abonelik seçenekleri
        Row(
          children: [
            // Aylık paket
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isYearly = false;
                  });
                },
                child: _buildSubscriptionCard(
                  title: 'Aylık',
                  price: monthlyPrice,
                  subtitle: 'her ay ödeme',
                  isSelected: !_isYearly,
                ),
              ),
            ),
            SizedBox(width: context.dimensions.spaceM),

            // Yıllık paket
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isYearly = true;
                  });
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildSubscriptionCard(
                      title: 'Yıllık',
                      price: yearlyPrice,
                      subtitle: 'aylık sadece $yearlyMonthlyPrice',
                      isSelected: _isYearly,
                      isMostPopular: true,
                    ),
                    // En popüler rozeti
                    Positioned(
                      top: -12,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF9800),
                              const Color(0xFFF57C00),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF9800).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.tag_fill,
                              color: AppColors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '%$savingsPercentage TASARRUF',
                              style: AppTextTheme.captionL.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),
        if (_isYearly) ...[
          // Yıllık abonelik avantajı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.lightbulb_fill,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Yıllık abonelikte toplam $savingsPercentage% tasarruf edersiniz!',
                    style: AppTextTheme.captionL.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubscriptionCard({
    required String title,
    required String price,
    required String subtitle,
    required bool isSelected,
    bool isMostPopular = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                  spreadRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seçim işareti ve başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextTheme.headline5.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color:
                        isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(
                          CupertinoIcons.checkmark,
                          color: AppColors.white,
                          size: 14,
                        ),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fiyat
          Text(
            price,
            style: AppTextTheme.headline3.copyWith(
              fontWeight: FontWeight.w800,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),

          // Alt açıklama
          Text(
            subtitle,
            style: AppTextTheme.captionL.copyWith(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.8)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton() {
    return Column(
      children: [
        // Satın alma butonu
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                const Color(0xFF00796B), // Koyu yeşil
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isPurchasePending
                  ? null
                  : () => _buyProduct(_getSelectedProduct()),
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.white.withOpacity(0.05),
              child: Center(
                child: _isPurchasePending
                    ? const CupertinoActivityIndicator(
                        color: Colors.white,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.star_fill,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Premium\'a Yükselt',
                            style: AppTextTheme.headline5.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Güvenli ödeme bilgisi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.shield_fill,
                color: Color(0xFF607D8B),
                size: 18,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: RichText(
                  text: TextSpan(
                    style: AppTextTheme.body.copyWith(
                      color: const Color(0xFF607D8B),
                    ),
                    children: const [
                      TextSpan(
                        text: 'Güvenli Ödeme',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' • '),
                      TextSpan(text: '7 Gün İade Garantisi'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Ürün ID'sine göre fiyatı bul
  String _findProductPrice(String productId) {
    try {
      final product = _products.firstWhere((p) => p.id == productId);
      return product.price;
    } catch (e) {
      return productId.contains('monthly')
          ? AppConstants.defaultMonthlyPrice
          : AppConstants.defaultYearlyPrice;
    }
  }

  // Yıllık aboneliğin aylık fiyatını hesapla
  String _calculateMonthlyPrice(String yearlyProductId) {
    try {
      final product = _products.firstWhere((p) => p.id == yearlyProductId);
      final price = product.rawPrice / 12;
      return "\$${price.toStringAsFixed(2)}";
    } catch (e) {
      return AppConstants.defaultMonthlyOfYearlyPrice; // Varsayılan değer
    }
  }

  // Seçilen ürünü döndür
  ProductDetails _getSelectedProduct() {
    final String productId = _isYearly
        ? AppConstants.subscriptionYearlyId
        : AppConstants.subscriptionMonthlyId;

    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      // Ürün bulunamadıysa ve liste boş değilse ilk ürünü döndür
      if (_products.isNotEmpty) {
        return _products.first;
      }

      // Hata fırlat - bu durumda kullanıcıya hata mesajı gösterilecek
      throw Exception('Seçilen ürün bulunamadı');
    }
  }

  // Hata durumu gösterimi
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.exclamationmark_circle,
              color: AppColors.warning,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Abonelik bilgilerini şu anda yükleyemiyoruz',
            style: AppTextTheme.headline5.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Lütfen internet bağlantınızı kontrol edip tekrar deneyin',
            style: AppTextTheme.body.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            width: 200,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _initInAppPurchase,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.refresh,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tekrar Dene',
                        style: AppTextTheme.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Hata bildirimi
  Widget _buildErrorNotification() {
    return Positioned(
      top: 10,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.error.withOpacity(0.9),
              AppColors.error,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: AppTextTheme.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
              child: const Icon(
                CupertinoIcons.clear_circled_solid,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Yükleniyor overlay'i
  Widget _buildLoadingOverlay() {
    return Container(
      color: AppColors.black.withOpacity(0.7),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 24,
              horizontal: 32,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoActivityIndicator(
                  radius: 16,
                ),
                const SizedBox(height: 20),
                Text(
                  'Satın alma işleniyor...',
                  style: AppTextTheme.headline5.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lütfen bekleyin',
                  style: AppTextTheme.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

// Örnek test kodu
void testInAppPurchase() async {
  // Test modunu etkinleştir
  InAppPurchase.instance.isAvailable().then((available) {
    if (available) {
      AppLogger.i('In-app purchase kullanılabilir');
      // Test ürünlerini sorgula
      final Set<String> ids = {
        AppConstants.subscriptionMonthlyId,
        AppConstants.subscriptionYearlyId,
      };
      InAppPurchase.instance.queryProductDetails(ids).then((response) {
        if (response.notFoundIDs.isNotEmpty) {
          AppLogger.w('Bulunamayan ürünler: ${response.notFoundIDs}');
        }
        for (final product in response.productDetails) {
          AppLogger.i('Ürün bulundu: ${product.id} - ${product.price}');
        }
      });
    }
  });
}
