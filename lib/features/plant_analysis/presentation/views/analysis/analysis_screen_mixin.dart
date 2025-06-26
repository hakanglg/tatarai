part of 'analysis_screen.dart';

mixin _AnalysisScreenMixin on State<AnalysisScreen> {
  // Çekilen fotoğrafın dosya yolu
  File? _selectedImage;

  // Konum ve tarla adı için kontrolcüler
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _fieldNameController = TextEditingController();

  // Konum servisi
  final LocationService _locationService = LocationService();

  // Cihaz bilgisi için
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  // Konum seçim verileri
  List<Province> _provinces = [];
  List<District> _districts = [];
  List<Neighborhood> _neighborhoods = [];

  // Gelecekte kullanılabilecek değişkenler (şu an pasif)
  // final int _selectedProvinceIndex = 0;
  // final int _selectedDistrictIndex = 0;
  // final int _selectedNeighborhoodIndex = 0;
  // final bool _districtsLoaded = false;
  // final bool _neighborhoodsLoaded = false;

  // Seçilen konum değerleri
  Province? _selectedProvince;
  District? _selectedDistrict;
  Neighborhood? _selectedNeighborhood;

  // Yükleniyor durumları
  bool _loadingProvinces = false;
  bool _loadingDistricts = false;
  bool _loadingNeighborhoods = false;

  // Son navigasyon yapılan analiz ID'sini tutmak için
  String? _lastNavigatedAnalysisId;

  // Görüntü seçici
  final ImagePicker _imagePicker = ImagePicker();

  // Animasyon kontrolcüsü
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void dispose() {
    _locationController.dispose();
    _fieldNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Animasyonları başlat
  void _initializeAnimations() {
    AppLogger.i('AnalysisScreen - Animasyonlar başlatılıyor');
    try {
      if (!mounted) {
        AppLogger.w(
            'AnalysisScreen - Widget mounted değil, animasyonlar başlatılamadı');
        return;
      }

      final vsync = this as TickerProvider;
      _animationController = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 300),
      );

      _scaleAnimation = Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Sprung(30),
        ),
      );

      _fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOut,
        ),
      );

      // Animasyonu başlat
      if (mounted) {
        _animationController.forward();
        AppLogger.i('AnalysisScreen - Animasyonlar başarıyla başlatıldı');
      }
    } catch (e, stackTrace) {
      AppLogger.e(
          'AnalysisScreen - Animasyon başlatma hatası: $e\n$stackTrace');
    }
  }

  // Emülatör kontrolü (şu an kullanılmıyor ama gelecekte yararlı olabilir)
  Future<void> _checkEmulator() async {
    // TODO: Emülatör kontrolü gerekirse buraya kod eklenebilir
    AppLogger.i('Device check completed');
  }

  // Fotoğraf seçim menüsünü göster
  Future<void> _showPhotoSourceDialog() async {
    if (!mounted) return;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          'photo_source_description'.locale(context),
          style: AppTextTheme.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        // message: Text(
        //   'photo_source_description'.locale(context),
        //   style: AppTextTheme.bodyMedium,
        // ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: Text('camera'.locale(context)),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: Text('gallery'.locale(context)),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('cancel'.locale(context)),
        ),
      ),
    );
  }

  // Fotoğraf seç
  Future<void> _pickImage(ImageSource source) async {
    try {
      // Kamera izni kontrolü
      if (source == ImageSource.camera) {
        final hasPermission = await PermissionManager.requestPermission(
          AppPermissionType.camera,
          context: context,
        );
        if (!hasPermission) {
          if (!mounted) return;
          AppLogger.w('Kamera izni reddedildi');
          return;
        }
      }

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile != null) {
        if (!mounted) return;

        setState(() {
          _selectedImage = File(pickedFile.path);
        });

        // Hafif titreşim geri bildirimi
        HapticFeedback.lightImpact();

        // Animasyonu başlat
        _animationController.forward(from: 0.0);

        AppLogger.i('Fotoğraf seçildi: ${pickedFile.path}');
      } else {
        AppLogger.i('Fotoğraf seçimi iptal edildi');
      }
    } catch (e) {
      AppLogger.e('Fotoğraf seçimi hatası: $e');
      if (!mounted) return;

      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('error'.locale(context)),
          content: Text('photo_selection_error'.locale(context)),
          actions: [
            CupertinoDialogAction(
              child: Text('ok'.locale(context)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  // Fotoğraf seçenekleri menüsünü göster
  Future<void> _showImageOptionsMenu() async {
    if (!mounted) return;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          'photo_ops'.locale(context),
          style: AppTextTheme.bodyLarge,
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showPhotoSourceDialog();
            },
            child: Text('change_photo'.locale(context)),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedImage = null;
              });
              AppLogger.i('Fotoğraf kaldırıldı');
            },
            child: Text('delete_photo'.locale(context)),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('cancel'.locale(context)),
        ),
      ),
    );
  }

  /// Hata mesajını göster
  Future<void> _showErrorDialog(String message,
      {bool needsPremium = false}) async {
    if (!mounted) return;

    if (needsPremium) {
      // PaywallManager kullanarak paywall'ı aç
      PaywallManager.showPaywall(
        context,
        displayCloseButton: true,
        onPremiumPurchased: () {
          AppLogger.i('Premium satın alındı - Analysis ekranından');
        },
        onError: (error) {
          AppLogger.e('Analysis screen paywall hatası: $error');
        },
      );
    } else {
      // Normal hata mesajı göster
      AppDialogManager.showErrorDialog(
        context: context,
        title: 'error_title'.locale(context),
        message: message,
      );
    }
  }

  /// İl seçim diyaloğunu göster
  void _showProvinceSelection() {
    if (_loadingProvinces) {
      _showLoadingDialog('provinces_loading'.locale(context));
      return;
    }

    if (_provinces.isEmpty) {
      _loadProvinces();
      _showErrorDialog('provinces_not_loaded'.locale(context));
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('select_province'.locale(context)),
        message: Text('select_province_desc'.locale(context)),
        actions: _provinces
            .map((province) => CupertinoActionSheetAction(
                  onPressed: () {
                    setState(() {
                      _selectedProvince = province;
                      _updateLocationText();
                    });
                    Navigator.pop(context);

                    // İl seçildiğinde ilçeleri yükle
                    _loadDistricts(province).then((_) {
                      // İlçeler yüklendikten sonra ilçe seçim diyaloğunu otomatik göster
                      if (_districts.isNotEmpty) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _showDistrictSelection();
                        });
                      }
                    });
                  },
                  child: Text(province.name),
                ))
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: Text('cancel'.locale(context)),
        ),
      ),
    );
  }

  /// İlçe seçim diyaloğunu göster
  void _showDistrictSelection() {
    if (_selectedProvince == null) {
      _showErrorDialog('select_province_first'.locale(context));
      return;
    }

    if (_loadingDistricts) {
      _showLoadingDialog('districts_loading'.locale(context));
      return;
    }

    if (_districts.isEmpty) {
      _loadDistricts(_selectedProvince!);
      _showErrorDialog('districts_not_loaded'.locale(context));
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('select_district'.locale(context)),
        message: Text('select_district_desc'.locale(context)),
        actions: _districts
            .map((district) => CupertinoActionSheetAction(
                  onPressed: () {
                    setState(() {
                      _selectedDistrict = district;
                      _updateLocationText();
                    });
                    Navigator.pop(context);

                    // İlçe seçildiğinde mahalleleri yükle
                    _loadNeighborhoods(_selectedProvince!, district).then((_) {
                      // Mahalleler yüklendikten sonra mahalle seçim diyaloğunu otomatik göster
                      if (_neighborhoods.isNotEmpty) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          _showNeighborhoodSelection();
                        });
                      }
                    });
                  },
                  child: Text(district.name),
                ))
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: Text('cancel'.locale(context)),
        ),
      ),
    );
  }

  /// Mahalle seçim diyaloğunu göster
  void _showNeighborhoodSelection() {
    if (_selectedDistrict == null) {
      _showErrorDialog('select_district_first'.locale(context));
      return;
    }

    if (_loadingNeighborhoods) {
      _showLoadingDialog('neighborhoods_loading'.locale(context));
      return;
    }

    if (_neighborhoods.isEmpty) {
      _loadNeighborhoods(_selectedProvince!, _selectedDistrict!);
      _showErrorDialog('neighborhoods_not_loaded'.locale(context));
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('select_neighborhood'.locale(context)),
        message: Text('select_neighborhood_desc'.locale(context)),
        actions: _neighborhoods
            .map((neighborhood) => CupertinoActionSheetAction(
                  onPressed: () {
                    setState(() {
                      _selectedNeighborhood = neighborhood;
                      _updateLocationText();
                    });
                    Navigator.pop(context);

                    // Tüm konum seçimleri tamamlandığında, isteğe bağlı olarak tarla adı seçimine yönlendirebiliriz
                    // veya direkt olarak analiz sürecine odaklanmasını sağlayabiliriz
                    if (_selectedImage != null) {
                      // Eğer görsel zaten seçilmiş ise, kullanıcının analiz butonuna odaklanmasına yardımcı ol
                      HapticFeedback.mediumImpact();
                    } else {
                      // Görsel seçilmemişse, kullanıcıyı görsel seçmeye yönlendir
                      Future.delayed(const Duration(milliseconds: 300), () {
                        _showPhotoSourceDialog();
                      });
                    }
                  },
                  child: Text(neighborhood.name),
                ))
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: Text('cancel'.locale(context)),
        ),
      ),
    );
  }

  /// Yükleniyor diyaloğunu göster
  void _showLoadingDialog(String message) {
    if (!mounted) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );

    // 2 saniye sonra otomatik kapat
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
    });
  }

  /// Yapay zeka analizi başlatma
  void _startAnalysis() async {
    if (_selectedImage == null) {
      _showErrorDialog('select_photo_first'.locale(context));
      return;
    }

    // Dil kontrolü ile location validation
    final currentLanguage =
        LocalizationManager.instance.currentLocale.languageCode;

    if (currentLanguage == 'tr') {
      // Türkçe için il/ilçe/mahalle kontrolü
      if (_selectedProvince == null ||
          _selectedDistrict == null ||
          _selectedNeighborhood == null) {
        _showErrorDialog('select_location_first'.locale(context));
        return;
      }
    } else {
      // Diğer diller için text field kontrolü
      if (_locationController.text.trim().isEmpty) {
        _showErrorDialog('select_location_first'.locale(context));
        return;
      }
    }

    // Kullanıcının authentication durumunu kontrol et
    final authState = context.read<AuthCubit>().state;
    if (authState is! AuthAuthenticated) {
      // Eğer kullanıcı authenticated değilse, anonim giriş yapmaya çalış
      AppLogger.w('Kullanıcı authenticated değil, anonim giriş yapılıyor...');
      try {
        await context.read<AuthCubit>().signInAnonymously();
        // Giriş sonrası tekrar kontrol et
        final newAuthState = context.read<AuthCubit>().state;
        if (newAuthState is! AuthAuthenticated) {
          _showErrorDialog('auth_required_for_analysis'.locale(context));
          return;
        }
      } catch (e) {
        AppLogger.e('Anonim giriş hatası: $e');
        _showErrorDialog('auth_login_error'.locale(context));
        return;
      }
    }

    // Kullanıcının analiz kredilerini kontrol et
    final authenticatedState =
        context.read<AuthCubit>().state as AuthAuthenticated;
    final currentUser = authenticatedState.user;

    AppLogger.i(
        'Kullanıcının analiz kredileri kontrol ediliyor: ${currentUser.analysisCredits}, Premium: ${currentUser.isPremium}');

    // Real-time credit check from Firestore (don't trust cached AuthCubit data)
    try {
      final firestoreService = ServiceLocator.get<FirestoreService>();
      final userDoc = await firestoreService.firestore
          .collection('users')
          .doc(currentUser.id)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        final realTimeCredits = userData?['analysisCredits'] ?? 0;
        final realTimePremium = userData?['isPremium'] ?? false;

        AppLogger.i(
            'Real-time Firestore credit check - User: ${currentUser.id}, Credits: $realTimeCredits, Premium: $realTimePremium');

        // Use real-time Firestore data for validation
        if (!realTimePremium && realTimeCredits <= 0) {
          AppLogger.w(
              'Kullanıcının analiz kredisi yok (Firestore real-time check), premium popup gösteriliyor');
          await _showErrorDialog(
            'free_analysis_limit_reached'.locale(context),
            needsPremium: true,
          );
          return;
        }

        AppLogger.i('Credit validation passed - proceeding with analysis');
      } else {
        AppLogger.w('User document not found in Firestore, using cached data');

        // Fallback to cached data if Firestore document doesn't exist
        if (!currentUser.isPremium && currentUser.analysisCredits <= 0) {
          AppLogger.w(
              'Kullanıcının analiz kredisi yok (fallback check), premium popup gösteriliyor');
          await _showErrorDialog(
            'free_analysis_limit_reached'.locale(context),
            needsPremium: true,
          );
          return;
        }
      }
    } catch (firestoreError) {
      AppLogger.w(
          'Firestore credit check failed, using cached data: $firestoreError');

      // Fallback to cached data if Firestore query fails
      if (!currentUser.isPremium && currentUser.analysisCredits <= 0) {
        AppLogger.w(
            'Kullanıcının analiz kredisi yok (fallback check), premium popup gösteriliyor');
        await _showErrorDialog(
          'free_analysis_limit_reached'.locale(context),
          needsPremium: true,
        );
        return;
      }
    }

    // Firebase Auth current user kontrolü
    final firebaseUser = FirebaseAuth.instance.currentUser;
    AppLogger.i(
        'Firebase Auth current user: ${firebaseUser?.uid ?? "null"} (anonim: ${firebaseUser?.isAnonymous ?? false})');

    if (firebaseUser == null) {
      AppLogger.w('Firebase Auth current user null, 2 saniye bekleniyor...');
      // 2 saniye bekle ve tekrar kontrol et
      await Future.delayed(const Duration(seconds: 2));
      final retryFirebaseUser = FirebaseAuth.instance.currentUser;

      if (retryFirebaseUser == null) {
        _showErrorDialog('firebase_auth_error'.locale(context));
        return;
      }

      AppLogger.i(
          'Firebase Auth current user (retry): ${retryFirebaseUser.uid} (anonim: ${retryFirebaseUser.isAnonymous})');
    }

    // Haptic feedback ekle
    HapticFeedback.heavyImpact();

    // Plant Analysis Cubit Direct üzerinden analizi başlat
    context.read<PlantAnalysisCubitDirect>().analyzeImageDirect(
          imageFile: _selectedImage!,
          user: currentUser,
          location: _locationController.text.trim(),
          province: _selectedProvince?.name,
          district: _selectedDistrict?.name,
          neighborhood: _selectedNeighborhood?.name,
          fieldName: _fieldNameController.text.trim().isNotEmpty
              ? _fieldNameController.text.trim()
              : null,
        );
  }

  /// İlleri API'den yükle
  Future<void> _loadProvinces() async {
    if (!mounted) return;

    setState(() {
      _loadingProvinces = true;
    });

    try {
      final provinces = await _locationService.getProvinces();

      if (!mounted) return;

      setState(() {
        _provinces = provinces;
        _loadingProvinces = false;
      });
    } catch (e) {
      if (!mounted) return;

      AppLogger.e('İller yüklenirken hata: $e');
      setState(() {
        _loadingProvinces = false;
      });
      _showErrorDialog('provinces_load_error'.locale(context));
    }
  }

  /// Seçilen ile göre ilçeleri yükle
  Future<void> _loadDistricts(Province province) async {
    if (!mounted) return;

    setState(() {
      _loadingDistricts = true;
      _districts = [];
      _selectedDistrict = null;
      _neighborhoods = [];
      _selectedNeighborhood = null;
      _updateLocationText();
    });

    try {
      final districts = await _locationService.getDistricts(province.name);

      if (!mounted) return;

      setState(() {
        _districts = districts;
        _loadingDistricts = false;
      });
    } catch (e) {
      if (!mounted) return;

      AppLogger.e('İlçeler yüklenirken hata: $e');
      setState(() {
        _loadingDistricts = false;
      });
      _showErrorDialog('districts_load_error'.locale(context));
    }
  }

  /// Seçilen ilçeye göre mahalleleri yükle
  Future<void> _loadNeighborhoods(Province province, District district) async {
    if (!mounted) return;

    setState(() {
      _loadingNeighborhoods = true;
      _neighborhoods = [];
      _selectedNeighborhood = null;
      _updateLocationText();
    });

    try {
      final neighborhoods =
          await _locationService.getNeighborhoods(province.name, district.name);

      if (!mounted) return;

      setState(() {
        _neighborhoods = neighborhoods;
        _loadingNeighborhoods = false;
      });
    } catch (e) {
      if (!mounted) return;

      AppLogger.e('Mahalleler yüklenirken hata: $e');
      setState(() {
        _loadingNeighborhoods = false;
      });
      _showErrorDialog('neighborhoods_load_error'.locale(context));
    }
  }

  /// Konum metin alanını güncelle
  void _updateLocationText() {
    String locationText = '';

    if (_selectedProvince != null) {
      locationText = _selectedProvince!.name;

      if (_selectedDistrict != null) {
        locationText += '/${_selectedDistrict!.name}';

        if (_selectedNeighborhood != null) {
          locationText += '/${_selectedNeighborhood!.name}';
        }
      }
    }

    _locationController.text = locationText;
  }

  // Premium navigation artık HomePremiumCard widget'ı içinde handle ediliyor
}
