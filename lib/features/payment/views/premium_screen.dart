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
import 'package:tatarai/features/auth/models/auth_state.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _initInAppPurchase();
    _animationController.forward();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _animationController.dispose();
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
        backgroundColor: CupertinoColors.systemBackground,
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
                            padding: EdgeInsets.symmetric(
                              horizontal: context.dimensions.paddingL,
                              vertical: context.dimensions.paddingM,
                            ),
                            child: _buildFeaturesList(),
                          ),
                        ),
                      ),

                      // Paket seçimi
                      if (!isPremium && !_isLoading && _errorMessage == null)
                        SliverToBoxAdapter(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Padding(
                              padding:
                                  EdgeInsets.all(context.dimensions.paddingL),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Abonelik Seçenekleri',
                                    style: AppTextTheme.headline5.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: context.dimensions.spaceM),
                                  _buildSubscriptionOptions(),
                                  SizedBox(height: context.dimensions.spaceL),
                                  _buildPurchaseButton(),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Boşluk
                      SliverToBoxAdapter(
                        child:
                            SizedBox(height: context.dimensions.spaceXXL * 2),
                      ),
                    ],
                  ),

                  // Yükleme göstergesi
                  if (_isLoading)
                    Positioned.fill(
                      child: _buildLoadingOverlay(),
                    ),

                  // Hata mesajları
                  if (_errorMessage != null)
                    Positioned.fill(
                      child: _buildErrorOverlay(),
                    ),

                  // Premium kullanıcı için overlay
                  if (isPremium)
                    Positioned.fill(
                      child: _buildPremiumOverlay(),
                    ),

                  // Alt bölüm - Gizlilik ve koşullar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildFooter(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(bool isPremium) {
    return Container(
      padding: EdgeInsets.all(context.dimensions.paddingL),
      child: Column(
        children: [
          // Logo/İkon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFCA70EF),
                  Color(0xFF9747FF),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9747FF).withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.star_fill,
                color: CupertinoColors.white,
                size: 40,
              ),
            ),
          ),
          SizedBox(height: context.dimensions.spaceM),

          // Başlık
          Text(
            isPremium ? 'Premium Üyeliğiniz Aktif' : 'Premium\'a Yükselin',
            style: AppTextTheme.headline2.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.dimensions.spaceM),

          // Açıklama
          Text(
            isPremium
                ? 'Tüm premium özelliklerden yararlanıyorsunuz. Teşekkür ederiz!'
                : 'Daha fazla analiz, daha az bekleyiş. Tüm potansiyelinizi ortaya çıkarın.',
            style: AppTextTheme.bodyText1.copyWith(
              color: CupertinoColors.systemGrey,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      _FeatureItem(
        icon: CupertinoIcons.infinite,
        title: 'Sınırsız Analiz',
        description: 'Kısıtlama olmadan istediğiniz kadar bitki analizi yapın',
        color: const Color(0xFF9747FF),
      ),
      _FeatureItem(
        icon: CupertinoIcons.bolt_fill,
        title: 'Öncelikli İşleme',
        description: 'Analizleriniz premium kuyruğunda hızla işlenir',
        color: const Color(0xFFFF9500),
      ),
      _FeatureItem(
        icon: CupertinoIcons.doc_chart_fill,
        title: 'Detaylı Raporlar',
        description: 'Bitki sağlığı ve bakımı için kapsamlı bilgiler alın',
        color: const Color(0xFF34C759),
      ),
      _FeatureItem(
        icon: CupertinoIcons.cloud_download_fill,
        title: 'PDF Dışa Aktarma',
        description: 'Tüm raporlarınızı PDF formatında kaydedebilirsiniz',
        color: const Color(0xFF007AFF),
      ),
    ];

    return Column(
      children: features.map((feature) {
        return _buildFeatureItem(feature);
      }).toList(),
    );
  }

  Widget _buildFeatureItem(_FeatureItem feature) {
    return Container(
      margin: EdgeInsets.only(bottom: context.dimensions.spaceM),
      padding: EdgeInsets.all(context.dimensions.paddingM),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey5.withOpacity(0.5),
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
                  style: AppTextTheme.headline6.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: context.dimensions.spaceXXS),
                Text(
                  feature.description,
                  style: AppTextTheme.bodyText2.copyWith(
                    color: CupertinoColors.systemGrey,
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
        : '₺29,99';
    final String yearlyPrice = hasProducts
        ? _findProductPrice(AppConstants.subscriptionYearlyId)
        : '₺199,99';

    // Yıllık fiyatın aylık karşılığını hesapla
    final String yearlyMonthlyPrice = hasProducts
        ? _calculateMonthlyPrice(AppConstants.subscriptionYearlyId)
        : '₺16,67';

    // Yıllık abone olunduğunda tasarruf oranı
    final double savingsPercentage = 45; // Varsayılan olarak %45 tasarruf

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
                          color: CupertinoColors.white,
                          size: 12,
                        ),
                        SizedBox(width: context.dimensions.spaceXXS),
                        Text(
                          '%$savingsPercentage tasarruf',
                          style: AppTextTheme.caption.copyWith(
                            color: CupertinoColors.white,
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
        color: isSelected
            ? AppColors.primary.withOpacity(0.05)
            : CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(context.dimensions.radiusL),
        border: Border.all(
          color: isSelected ? AppColors.primary : CupertinoColors.systemGrey5,
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
                style: AppTextTheme.subtitle1.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : CupertinoColors.label,
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.primary
                      : CupertinoColors.systemGrey5,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : CupertinoColors.systemGrey4,
                    width: 1,
                  ),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(
                          CupertinoIcons.checkmark,
                          color: CupertinoColors.white,
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
              color: isSelected ? AppColors.primary : CupertinoColors.label,
            ),
          ),
          SizedBox(height: context.dimensions.spaceXXS),
          // Alt açıklama
          Text(
            subtitle,
            style: AppTextTheme.caption.copyWith(
              color: CupertinoColors.systemGrey,
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
              color: CupertinoColors.systemGreen,
              size: 14,
            ),
            SizedBox(width: context.dimensions.spaceXS),
            Text(
              'Güvenli Ödeme & 7 Gün İade Garantisi',
              style: AppTextTheme.caption.copyWith(
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: EdgeInsets.all(context.dimensions.paddingM),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.withOpacity(0.7),
            border: const Border(
              top: BorderSide(
                color: CupertinoColors.systemGrey5,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Aboneliğiniz otomatik olarak yenilenir. İstediğiniz zaman iptal edebilirsiniz.',
                  style: AppTextTheme.caption.copyWith(
                    color: CupertinoColors.systemGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.dimensions.spaceS),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {},
                      child: Text(
                        'Gizlilik Politikası',
                        style: AppTextTheme.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      '•',
                      style: TextStyle(
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {},
                      child: Text(
                        'Kullanım Koşulları',
                        style: AppTextTheme.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: CupertinoColors.systemBackground.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(radius: 20),
            SizedBox(height: context.dimensions.spaceM),
            Text(
              'Abonelik bilgileri yükleniyor...',
              style: AppTextTheme.bodyText1.copyWith(
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: CupertinoColors.systemBackground.withOpacity(0.9),
      padding: EdgeInsets.all(context.dimensions.paddingL),
      child: Center(
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
                size: 40,
              ),
            ),
            SizedBox(height: context.dimensions.spaceM),
            Text(
              'Bir Hata Oluştu',
              style: AppTextTheme.headline5.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: context.dimensions.spaceXS),
            Text(
              _errorMessage ?? 'Bilinmeyen bir hata oluştu.',
              textAlign: TextAlign.center,
              style: AppTextTheme.bodyText1.copyWith(
                color: CupertinoColors.systemGrey,
              ),
            ),
            SizedBox(height: context.dimensions.spaceL),
            AppButton(
              text: 'Tekrar Dene',
              icon: CupertinoIcons.refresh,
              type: AppButtonType.secondary,
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadProducts();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumOverlay() {
    return Container(
      color: CupertinoColors.systemBackground.withOpacity(0.9),
      padding: EdgeInsets.all(context.dimensions.paddingL),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFCA70EF),
                    Color(0xFF9747FF),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9747FF).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.checkmark_alt_circle_fill,
                color: CupertinoColors.white,
                size: 60,
              ),
            ),
            SizedBox(height: context.dimensions.spaceL),
            Text(
              'Premium Üyeliğiniz Aktif',
              style: AppTextTheme.headline4.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: context.dimensions.spaceM),
            Text(
              'Tüm premium özelliklerimizden yararlanabilirsiniz. Bizi tercih ettiğiniz için teşekkür ederiz!',
              textAlign: TextAlign.center,
              style: AppTextTheme.bodyText1.copyWith(
                color: CupertinoColors.systemGrey,
                height: 1.4,
              ),
            ),
            SizedBox(height: context.dimensions.spaceXL),
            AppButton(
              text: 'Anasayfaya Dön',
              icon: CupertinoIcons.home,
              type: AppButtonType.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // Ürün ID'sine göre fiyatı bul
  String _findProductPrice(String productId) {
    try {
      final product = _products.firstWhere((p) => p.id == productId);
      return product.price;
    } catch (e) {
      return productId.contains('monthly') ? '₺29,99' : '₺199,99';
    }
  }

  // Yıllık aboneliğin aylık fiyatını hesapla
  String _calculateMonthlyPrice(String yearlyProductId) {
    try {
      final product = _products.firstWhere((p) => p.id == yearlyProductId);
      final price = product.rawPrice / 12;
      return price.toStringAsFixed(2).replaceAll('.', ',');
    } catch (e) {
      return '₺16,67'; // Varsayılan değer
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
