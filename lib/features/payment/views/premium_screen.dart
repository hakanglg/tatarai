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
        middle: const Text('Premium'),
        border: const Border(
          bottom: BorderSide(color: Colors.transparent),
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: SafeArea(
          bottom: false,
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              return Stack(
                children: [
                  // Ana içerik
                  CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Üst kısım - Premium özellikleri
                      SliverToBoxAdapter(
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

                      // Premium özellikleri
                      SliverToBoxAdapter(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Premium Avantajları',
                                  style: AppTextTheme.headline4.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
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
                                padding: const EdgeInsets.all(16),
                                child: _isLoading
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(24),
                                          child: CupertinoActivityIndicator(),
                                        ),
                                      )
                                    : _products.isEmpty
                                        ? Center(
                                            child: Column(
                                              children: [
                                                const Icon(
                                                  CupertinoIcons
                                                      .exclamationmark_circle,
                                                  color: AppColors.warning,
                                                  size: 48,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'Abonelik bilgilerini şu anda yükleyemiyoruz.',
                                                  style: AppTextTheme.body
                                                      .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 16),
                                                AppButton(
                                                  text: 'Tekrar Dene',
                                                  onPressed: _initInAppPurchase,
                                                  type: AppButtonType.secondary,
                                                  width: 200,
                                                ),
                                              ],
                                            ),
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Abonelik Seçenekleri',
                                                style: AppTextTheme.headline4
                                                    .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              _buildSubscriptionOptions(),
                                              const SizedBox(height: 24),
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
                  if (_errorMessage != null)
                    Positioned(
                      top: 10,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_triangle,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTextTheme.captionL.copyWith(
                                  color: AppColors.error,
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
                              child: Icon(
                                CupertinoIcons.clear_circled_solid,
                                color: AppColors.error.withOpacity(0.7),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Yükleniyor göstergesi
                  if (_isPurchasePending)
                    Container(
                      color: AppColors.black.withOpacity(0.5),
                      child: const Center(
                        child: CupertinoActivityIndicator(
                          radius: 15,
                          color: AppColors.white,
                        ),
                      ),
                    ),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.7),
                      AppColors.primary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.sparkles,
                    color: AppColors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium ? 'Premium Aktif' : 'TatarAI Premium',
                      style: AppTextTheme.headline3.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPremium
                          ? 'Tüm premium özelliklere erişiminiz var.'
                          : 'Daha fazla analiz ve özelleştirilmiş tarım asistanı',
                      style: AppTextTheme.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isPremium) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    color: AppColors.success,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Premium üyeliğiniz aktif. Tüm özelliklere sınırsız erişebilirsiniz.',
                      style: AppTextTheme.captionL.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildFeatureList() {
    final features = [
      _FeatureItem(
        title: 'Sınırsız Bitki Analizi',
        description:
            'Premium üyelik ile sınırsız bitki analizi yapabilirsiniz.',
        icon: CupertinoIcons.infinite,
        color: AppColors.primary,
      ),
      _FeatureItem(
        title: 'Öncelikli Analiz',
        description:
            'Analizleriniz öncelikli olarak yapılır, daha az beklersiniz.',
        icon: CupertinoIcons.timer,
        color: AppColors.info,
      ),
      _FeatureItem(
        title: 'İleri Teşhis ve Öneriler',
        description: 'Daha detaylı teşhis ve tedavi önerileri alırsınız.',
        icon: CupertinoIcons.doc_text_search,
        color: AppColors.success,
      ),
      _FeatureItem(
        title: 'Analiz Geçmişi',
        description: 'Tüm analiz geçmişinize sınırsız erişim sağlarsınız.',
        icon: CupertinoIcons.chart_bar_alt_fill,
        color: AppColors.warning,
      ),
    ];

    return features.map((feature) {
      return _buildFeatureItem(feature);
    }).toList();
  }

  Widget _buildFeatureItem(_FeatureItem feature) {
    return Container(
      margin: EdgeInsets.only(bottom: context.dimensions.spaceM),
      padding: EdgeInsets.all(context.dimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: feature.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(context.dimensions.radiusM),
            ),
            child: Center(
              child: Icon(
                feature.icon,
                color: feature.color,
                size: 26,
              ),
            ),
          ),
          SizedBox(width: context.dimensions.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: AppTextTheme.headline5.copyWith(
                    fontWeight: FontWeight.w600,
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
        ],
      ),
    );
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

    return Row(
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
              subtitle: 'aylık ödeme',
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
                  subtitle: 'yıllık ödeme (aylık $yearlyMonthlyPrice)',
                  isSelected: _isYearly,
                  isMostPopular: true,
                ),
                // En popüler rozeti
                Positioned(
                  top: -10,
                  right: -10,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.dimensions.paddingXS,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.circular(context.dimensions.radiusL),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
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
                          size: 12,
                        ),
                        SizedBox(width: context.dimensions.spaceXXS),
                        Text(
                          '%$savingsPercentage tasarruf',
                          style: AppTextTheme.captionL.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
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
      padding: EdgeInsets.all(context.dimensions.paddingM),
      decoration: BoxDecoration(
        color:
            isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.white,
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.divider,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seçim işareti
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextTheme.captionL.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                    width: 1,
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
          SizedBox(height: context.dimensions.spaceS),
          // Fiyat
          Text(
            price,
            style: AppTextTheme.headline3.copyWith(
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: context.dimensions.spaceXXS),
          // Alt açıklama
          Text(
            subtitle,
            style: AppTextTheme.captionL.copyWith(
              color: AppColors.textSecondary,
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
        AppButton(
          text: 'Satın Al',
          icon: _isPurchasePending ? null : CupertinoIcons.star_fill,
          isLoading: _isPurchasePending,
          type: AppButtonType.primary,
          onPressed: _isPurchasePending
              ? null
              : () => _buyProduct(_getSelectedProduct()),
        ),
        SizedBox(height: context.dimensions.spaceM),
        // Bilgi mesajı
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.shield_fill,
              color: AppColors.primary,
              size: 14,
            ),
            SizedBox(width: context.dimensions.spaceXS),
            Text(
              'Güvenli Ödeme & 7 Gün İade Garantisi',
              style: AppTextTheme.captionL.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
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
