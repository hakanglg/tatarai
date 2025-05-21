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
  bool _isEmulator = false;

  // Konum seçim verileri
  List<Province> _provinces = [];
  List<District> _districts = [];
  List<Neighborhood> _neighborhoods = [];

  // Seçim indeksleri
  int _selectedProvinceIndex = 0;
  int _selectedDistrictIndex = 0;
  int _selectedNeighborhoodIndex = 0;

  // Veri yükleme durumları
  bool _districtsLoaded = false;
  bool _neighborhoodsLoaded = false;
  String? _fieldName;

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

  // Emülatör kontrolü
  Future<void> _checkEmulator() async {
    if (Platform.isIOS) {
      final iosInfo = await _deviceInfoPlugin.iosInfo;
      _isEmulator = !iosInfo.isPhysicalDevice;
    } else if (Platform.isAndroid) {
      final androidInfo = await _deviceInfoPlugin.androidInfo;
      _isEmulator = !androidInfo.isPhysicalDevice;
    }
  }

  // Fotoğraf seçim menüsünü göster
  Future<void> _showPhotoSourceDialog() async {
    if (!mounted) return;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          'Fotoğraf Seç',
          style: AppTextTheme.bodyLarge,
        ),
        message: Text(
          'Lütfen fotoğraf kaynağını seçin',
          style: AppTextTheme.bodyMedium,
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: Text('Kamera'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: Text('Galeri'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('İptal'),
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
          title: Text('Hata'),
          content: Text(
              'Fotoğraf seçilirken bir hata oluştu. Lütfen tekrar deneyin.'),
          actions: [
            CupertinoDialogAction(
              child: Text('Tamam'),
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
          'Fotoğraf Seçenekleri',
          style: AppTextTheme.bodyLarge,
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showPhotoSourceDialog();
            },
            child: Text('Yeni Fotoğraf Seç'),
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
            child: Text('Fotoğrafı Kaldır'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('İptal'),
        ),
      ),
    );
  }

  /// Hata mesajını göster
  Future<void> _showErrorDialog(String message,
      {bool needsPremium = false}) async {
    if (!mounted) return;

    if (needsPremium) {
      // Premium satın alma diyaloğunu göster
      final result = await AppDialogManager.showPremiumRequiredDialog(
        context: context,
        message: message,
        onPremiumButtonPressed: () {
          // Context extension'ı kullanarak paywall'ı aç
          context.showPaywall(
            onComplete: (_) {
              // Paywall kapandıktan sonra kullanıcı bilgilerini yenile
              if (mounted) {
                context.read<ProfileCubit>().refreshUserData();
              }
            },
          );
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

  /// Tarla adı giriş diyaloğunu göster
  void _showFieldNameDialog() {
    final TextEditingController controller = TextEditingController();
    controller.text = _fieldNameController.text;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('field_name'.locale(context)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'enter_field_name'.locale(context),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: false,
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.locale(context)),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              setState(() {
                _fieldNameController.text = controller.text.trim();
              });
              Navigator.pop(context);
            },
            child: Text('save'.locale(context)),
          ),
        ],
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
  void _startAnalysis() {
    if (_selectedImage == null) {
      _showErrorDialog('select_photo_first'.locale(context));
      return;
    }

    if (_selectedProvince == null ||
        _selectedDistrict == null ||
        _selectedNeighborhood == null) {
      _showErrorDialog('select_location_first'.locale(context));
      return;
    }

    // Haptic feedback ekle
    HapticFeedback.heavyImpact();

    // Konum ve tarla adını hazırla
    final String location = _locationController.text.trim();
    final String? fieldName = _fieldNameController.text.trim().isNotEmpty
        ? _fieldNameController.text.trim()
        : null;

    // Plant Analysis Cubit'i üzerinden analizi başlat
    context.read<PlantAnalysisCubit>().analyzeImage(
          _selectedImage!,
          location: location,
          province: _selectedProvince?.name,
          district: _selectedDistrict?.name,
          neighborhood: _selectedNeighborhood?.name,
          fieldName: fieldName,
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

  /// Premium sayfasına yönlendir
  void _navigateToPremium() {
    if (!mounted) return;

    // Context extension'ı kullanarak paywall'ı aç
    context.showPaywall(
      onComplete: (_) {
        // Paywall kapandıktan sonra kullanıcı bilgilerini yenile
        if (mounted) {
          context.read<ProfileCubit>().refreshUserData();
        }
      },
    );
  }
}
