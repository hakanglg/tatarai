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
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this as TickerProvider,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Animasyonu başlat
    _animationController.forward();

    // İlleri yükle
    _loadProvinces();

    // Emülatör kontrolü yap
    _checkIfEmulator().then((_) {
      // Uygulama başlangıcında izinleri kontrol et (emülatör değilse)
      if (!_isEmulator) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _requestPermissions();
        });
      } else {
        AppLogger.i('Emülatör tespit edildi, izin kontrolleri atlanıyor');
      }
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _fieldNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// İlleri API'den yükle
  Future<void> _loadProvinces() async {
    setState(() {
      _loadingProvinces = true;
    });

    try {
      final provinces = await _locationService.getProvinces();
      setState(() {
        _provinces = provinces;
        _loadingProvinces = false;
      });
    } catch (e) {
      AppLogger.e('İller yüklenirken hata: $e');
      setState(() {
        _loadingProvinces = false;
      });
      _showErrorDialog(
          'İller yüklenirken bir hata oluştu. Lütfen internet bağlantınızı kontrol edin.');
    }
  }

  /// Seçilen ile göre ilçeleri yükle
  Future<void> _loadDistricts(Province province) async {
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
      setState(() {
        _districts = districts;
        _loadingDistricts = false;
      });
    } catch (e) {
      AppLogger.e('İlçeler yüklenirken hata: $e');
      setState(() {
        _loadingDistricts = false;
      });
      _showErrorDialog(
          'İlçeler yüklenirken bir hata oluştu. Lütfen internet bağlantınızı kontrol edin.');
    }
  }

  /// Seçilen ilçeye göre mahalleleri yükle
  Future<void> _loadNeighborhoods(Province province, District district) async {
    setState(() {
      _loadingNeighborhoods = true;
      _neighborhoods = [];
      _selectedNeighborhood = null;
      _updateLocationText();
    });

    try {
      final neighborhoods =
          await _locationService.getNeighborhoods(province.name, district.name);
      setState(() {
        _neighborhoods = neighborhoods;
        _loadingNeighborhoods = false;
      });
    } catch (e) {
      AppLogger.e('Mahalleler yüklenirken hata: $e');
      setState(() {
        _loadingNeighborhoods = false;
      });
      _showErrorDialog(
          'Mahalleler yüklenirken bir hata oluştu. Lütfen internet bağlantınızı kontrol edin.');
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

  // İl seçim diyaloğunu göster
  void _showProvinceSelector() {
    // Haptic feedback ekle
    HapticFeedback.lightImpact();

    if (_loadingProvinces) {
      _showLoadingDialog('İller yükleniyor...');
      return;
    }

    if (_provinces.isEmpty) {
      _loadProvinces();
      _showErrorDialog('İller henüz yüklenmedi. Lütfen tekrar deneyin.');
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text("İl Seçin"),
          message: const Text("Bitkinin bulunduğu ili seçin"),
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
                            _showDistrictSelector();
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
            child: const Text("İptal"),
          ),
        );
      },
    );
  }

  // İlçe seçim diyaloğunu göster
  void _showDistrictSelector() {
    // Haptic feedback ekle
    HapticFeedback.lightImpact();

    if (_selectedProvince == null) {
      _showErrorDialog('Lütfen önce bir il seçin.');
      return;
    }

    if (_loadingDistricts) {
      _showLoadingDialog('İlçeler yükleniyor...');
      return;
    }

    if (_districts.isEmpty) {
      _loadDistricts(_selectedProvince!);
      _showErrorDialog('İlçeler henüz yüklenmedi. Lütfen tekrar deneyin.');
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text("İlçe Seçin"),
          message: Text("${_selectedProvince!.name} ilinin ilçesini seçin"),
          actions: _districts
              .map((district) => CupertinoActionSheetAction(
                    onPressed: () {
                      setState(() {
                        _selectedDistrict = district;
                        _updateLocationText();
                      });
                      Navigator.pop(context);

                      // İlçe seçildiğinde mahalleleri yükle
                      _loadNeighborhoods(_selectedProvince!, district)
                          .then((_) {
                        // Mahalleler yüklendikten sonra mahalle seçim diyaloğunu otomatik göster
                        if (_neighborhoods.isNotEmpty) {
                          Future.delayed(const Duration(milliseconds: 300), () {
                            _showNeighborhoodSelector();
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
            child: const Text("İptal"),
          ),
        );
      },
    );
  }

  // Mahalle seçim diyaloğunu göster
  void _showNeighborhoodSelector() {
    // Haptic feedback ekle
    HapticFeedback.lightImpact();

    if (_selectedProvince == null || _selectedDistrict == null) {
      _showErrorDialog('Lütfen önce il ve ilçe seçin.');
      return;
    }

    if (_loadingNeighborhoods) {
      _showLoadingDialog('Mahalleler yükleniyor...');
      return;
    }

    if (_neighborhoods.isEmpty) {
      _loadNeighborhoods(_selectedProvince!, _selectedDistrict!);
      _showErrorDialog('Mahalleler henüz yüklenmedi. Lütfen tekrar deneyin.');
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: const Text("Mahalle Seçin"),
          message: Text(
              "${_selectedProvince!.name}/${_selectedDistrict!.name} mahallesini seçin"),
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
                          _showPhotoOptions();
                        });
                      }
                    },
                    child: Text(neighborhood.name),
                  ))
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            isDestructiveAction: true,
            child: const Text("İptal"),
          ),
        );
      },
    );
  }

  // Tarla adı giriş diyaloğunu göster
  void _showFieldNameInput() {
    final TextEditingController customFieldController =
        TextEditingController(text: _fieldNameController.text);

    // Özel içerikli diyalog için hala showCupertinoDialog kullanıyoruz
    // Bu tür karmaşık diyalogları ayrı widget olarak geliştirmek daha iyi olabilir
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Tarla Adı'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: CupertinoTextField(
            controller: customFieldController,
            placeholder: 'Tarla adını girin',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('İptal'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Kaydet'),
            onPressed: () {
              if (customFieldController.text.trim().isNotEmpty) {
                setState(() {
                  _fieldNameController.text = customFieldController.text.trim();
                });
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // Fotoğraf ekleme seçeneklerini göster (Kamera veya Galeri)
  void _showPhotoOptions() {
    // Haptic feedback ekle
    HapticFeedback.mediumImpact();

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Fotoğraf Ekle'),
        message:
            const Text('Bitkinizin fotoğrafını eklemek için bir yöntem seçin'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _takePicture();
            },
            child: Text(
              'Kamera',
              style: AppTextTheme.largeBody.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImageFromGallery();
            },
            child: Text(
              'Galeri',
              style: AppTextTheme.largeBody.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('İptal'),
        ),
      ),
    );
  }

  // Yükleniyor diyaloğunu göster
  void _showLoadingDialog(String message) {
    AppDialogManager.showLoadingDialog(
      context: context,
      message: message,
    );

    // 2 saniye sonra otomatik kapat
    Future.delayed(const Duration(seconds: 2), () {
      AppDialogManager.dismissDialog(context);
    });
  }

  // Fotoğraf çekme işlemi
  Future<void> _takePicture() async {
    try {
      // Haptic feedback ekle
      HapticFeedback.mediumImpact();

      AppLogger.i('Kamera açılıyor...');

      // Emülatörde ise hata gösterme
      if (_isEmulator) {
        AppLogger.i('Emülatörde fotoğraf çekme işlemi denendi');
        _showInfoDialog('Emülatörde kamera kullanımı',
            'Emülatörde gerçek kamera erişimi mümkün olmayabilir. Gerçek cihazda test etmeniz önerilir.');
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: AppConstants.imageQuality,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      // Kullanıcı kamera erişimini iptal ederse null dönebilir
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });

        // Resim eklendiğinde animasyon yap
        _animationController.reset();
        _animationController.forward();

        AppLogger.i('Fotoğraf çekildi: ${image.path}');
      } else {
        AppLogger.i('Kamera kullanımı iptal edildi');
      }
    } catch (e) {
      AppLogger.e('Fotoğraf çekilirken hata oluştu: $e');

      // Emülatörde ise farklı mesaj göster
      if (_isEmulator) {
        _showInfoDialog('Emülatörde Kamera Hatası',
            'Emülatörde kamera kullanımı genellikle çalışmaz. Gerçek bir cihazda test etmeniz önerilir.');
      } else {
        _showPermissionSettingsDialog();
      }
    }
  }

  // Bu metod artık PermissionManager tarafından yönetiliyor
  Future<void> _showPermissionSettingsDialog() async {
    // İzin isteği için PermissionManager kullan
    await PermissionManager.requestPermission(
      AppPermissionType.camera,
      context: context,
    );
  }

  // Bilgi diyaloğu göster
  void _showInfoDialog(String title, String message) {
    AppDialogManager.showInfoDialog(
      context: context,
      title: title,
      message: message,
    );
  }

  // Galeriden fotoğraf seçme işlemi
  Future<void> _pickImageFromGallery() async {
    try {
      // Haptic feedback ekle
      HapticFeedback.mediumImpact();

      AppLogger.i('Galeri açılıyor...');

      // Emülatörde özel bir uyarı gösterme gereği yok, genellikle çalışır

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: AppConstants.imageQuality,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });

        // Resim eklendiğinde animasyon yap
        _animationController.reset();
        _animationController.forward();

        AppLogger.i('Galeriden fotoğraf seçildi: ${image.path}');
      } else {
        AppLogger.i('Galeri kullanımı iptal edildi');
      }
    } catch (e) {
      AppLogger.e('Galeriden fotoğraf seçilirken hata oluştu: $e');

      // Emülatörde ise farklı mesaj göster
      if (_isEmulator) {
        _showInfoDialog('Emülatörde Galeri Hatası',
            'Emülatörde fotoğraf galerisi erişimi sorun yaşanabilir. Test fotoğrafları emülatöre eklenmiş mi kontrol edin.');
      } else {
        // İzinleri yeniden kontrol et
        await PermissionManager.requestPermission(AppPermissionType.photos,
            context: context);
      }
    }
  }

  // Yapay zeka analizi başlatma
  void _startAnalysis() {
    if (_selectedImage == null) {
      _showErrorDialog('Lütfen önce bir fotoğraf çekin veya galeriden seçin.');
      return;
    }

    if (_selectedProvince == null ||
        _selectedDistrict == null ||
        _selectedNeighborhood == null) {
      _showErrorDialog('Lütfen il, ilçe ve mahalle seçin.');
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
    // Kredi kontrolü ve premium kontrolü Cubit içinde yapılacak
    context.read<PlantAnalysisCubit>().analyzeImage(
          _selectedImage!,
          location: location,
          province: _selectedProvince?.name,
          district: _selectedDistrict?.name,
          neighborhood: _selectedNeighborhood?.name,
          fieldName: fieldName,
        );
  }

  // Hata mesajı gösterme
  Future<void> _showErrorDialog(String message,
      {bool needsPremium = false}) async {
    if (needsPremium) {
      // Premium satın alma diyaloğunu göster
      final result = await AppDialogManager.showPremiumRequiredDialog(
        context: context,
        message: message,
        onPremiumButtonPressed: _navigateToPremiumScreen,
      );
    } else {
      // Normal hata mesajı göster
      AppDialogManager.showErrorDialog(
        context: context,
        title: 'Hata',
        message: message,
      );
    }
  }

  // Premium satın alma sayfasına yönlendir
  void _navigateToPremiumScreen() {
    // Premium sayfasına yönlendirme
    AppLogger.i('Premium satın alma sayfasına yönlendiriliyor');
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const PremiumScreen(),
      ),
    );
  }

  // İzin isteme işlemi
  Future<void> _requestPermissions() async {
    try {
      AppLogger.i('Uygulama izinleri kontrol ediliyor...');

      List<AppPermissionType> requiredPermissions = [
        AppPermissionType.camera,
        if (Platform.isIOS)
          AppPermissionType.photos
        else
          AppPermissionType.storage,
      ];

      // İzinleri merkezi permisyon manager ile isteyelim
      final results = await PermissionManager.requestMultiplePermissions(
        requiredPermissions,
        context: context,
      );

      // İzin durumlarını loglayalım
      results.forEach((permission, isGranted) {
        AppLogger.i(
            'İzin durumu - ${permission.toString()}: ${isGranted ? 'Verildi' : 'Verilmedi'}');
      });

      // Tüm izinlerin verilip verilmediğini kontrol et
      bool allGranted = !results.values.contains(false);

      AppLogger.i('Tüm izinler verildi mi: $allGranted');
    } catch (e) {
      AppLogger.e('İzin isteme işlemi sırasında hata: $e');
    }
  }

  // Cihazın emülatör olup olmadığını kontrol et
  Future<void> _checkIfEmulator() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        // Android emülatör kontrolü
        _isEmulator = androidInfo.isPhysicalDevice == false ||
            androidInfo.model.contains('sdk') ||
            androidInfo.model.contains('emulator') ||
            androidInfo.model.contains('Android SDK');

        AppLogger.i(
            'Android cihaz: ${androidInfo.model}, Emülatör: $_isEmulator');
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        // iOS simülatör kontrolü
        _isEmulator = iosInfo.isPhysicalDevice == false ||
            iosInfo.model.toLowerCase().contains('simulator');

        AppLogger.i('iOS cihaz: ${iosInfo.model}, Simülatör: $_isEmulator');
      }
    } catch (e) {
      AppLogger.e('Emülatör kontrolü sırasında hata: $e');
      _isEmulator = false;
    }
  }

  // Resim seçenekleri menüsünü göster
  void _showImageOptionsMenu() {
    // Haptic feedback ekle
    HapticFeedback.mediumImpact();

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Fotoğraf İşlemleri'),
        message: const Text('Fotoğraf üzerinde ne yapmak istiyorsunuz?'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showPhotoOptions(); // Mevcut fotoğraf ekleme yöntemi
            },
            child: Text(
              'Değiştir',
              style: AppTextTheme.captionL.copyWith(
                fontWeight: FontWeight.w500,
                color: CupertinoColors.label,
              ),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _selectedImage = null; // Fotoğrafı sil
              });
              // Fotoğraf silindiğinde animasyon yap
              _animationController.reset();
              _animationController.forward();
            },
            isDestructiveAction: true,
            child: const Text('Fotoğrafı Sil'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
      ),
    );
  }
}
