import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tatarai/core/utils/permission_manager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/widgets/app_dialog_manager.dart';
import 'package:tatarai/core/theme/color_scheme.dart';
import 'package:tatarai/core/theme/dimensions.dart';
import 'package:tatarai/core/theme/text_theme.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/widgets/app_button.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_cubit.dart';
import 'package:tatarai/features/plant_analysis/models/location_models.dart';
import 'package:tatarai/features/plant_analysis/cubits/plant_analysis_state.dart';
import 'package:tatarai/features/plant_analysis/services/location_service.dart';
import 'package:tatarai/features/plant_analysis/views/analyses_result/analysis_result_screen.dart';
import 'package:tatarai/features/payment/views/premium_screen.dart';

/// Bitki analizi ekranı
/// Fotoğraf çekme, yükleme ve yapay zeka analizini başlatma
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
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
      vsync: this,
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
      // Widget hala ağaçta mı kontrol et
      if (!mounted) return;

      // Uygulama başlangıcında izinleri kontrol et (emülatör değilse)
      if (!_isEmulator) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _requestPermissions();
          }
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

      // Widget hala ağaçta mı kontrol et
      if (!mounted) return;

      setState(() {
        _provinces = provinces;
        _loadingProvinces = false;
      });
    } catch (e) {
      // Widget hala ağaçta mı kontrol et
      if (!mounted) return;

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

      // Widget hala ağaçta mı kontrol et
      if (!mounted) return;

      setState(() {
        _districts = districts;
        _loadingDistricts = false;
      });
    } catch (e) {
      // Widget hala ağaçta mı kontrol et
      if (!mounted) return;

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

      // Widget hala ağaçta mı kontrol et
      if (!mounted) return;

      setState(() {
        _neighborhoods = neighborhoods;
        _loadingNeighborhoods = false;
      });
    } catch (e) {
      // Widget hala ağaçta mı kontrol et
      if (!mounted) return;

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
              style: AppTextTheme.captionL.copyWith(
                fontWeight: FontWeight.w500,
                color: CupertinoColors.label,
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
              style: AppTextTheme.captionL.copyWith(
                fontWeight: FontWeight.w500,
                color: CupertinoColors.label,
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
    // Widget hala ağaçta mı kontrol et
    if (!mounted) return;

    AppDialogManager.showLoadingDialog(
      context: context,
      message: message,
    );

    // 2 saniye sonra otomatik kapat
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
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

      // Widget hala ağaçta mı kontrol et
      if (!mounted) return;

      // Kullanıcı kamera erişimini iptal ederse null dönebilir
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });

        // Resim eklendiğinde animasyon yap
        if (mounted) {
          _animationController.reset();
          _animationController.forward();
        }

        AppLogger.i('Fotoğraf çekildi: ${image.path}');
      } else {
        AppLogger.i('Kamera kullanımı iptal edildi');
      }
    } catch (e) {
      // Widget hala ağaçta mı kontrol et
      if (!mounted) return;

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
    // Widget hala ağaçta mı kontrol et
    if (!mounted) return;

    // İzin isteği için PermissionManager kullan
    await PermissionManager.requestPermission(
      AppPermissionType.camera,
      context: context,
    );
  }

  // Bilgi diyaloğu göster
  void _showInfoDialog(String title, String message) {
    // Widget hala ağaçta mı kontrol et
    if (!mounted) return;

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

      // Widget hala ağaçta mı kontrol et
      if (!mounted) return;

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });

        // Resim eklendiğinde animasyon yap
        if (mounted) {
          _animationController.reset();
          _animationController.forward();
        }

        AppLogger.i('Galeriden fotoğraf seçildi: ${image.path}');
      } else {
        AppLogger.i('Galeri kullanımı iptal edildi');
      }
    } catch (e) {
      // Widget hala ağaçta mı kontrol et
      if (!mounted) return;

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
    // Widget hala ağaçta mı kontrol et
    if (!mounted) return;

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

        // Widget hala ağaçta mı kontrol et
        if (!mounted) return;

        // Android emülatör kontrolü
        _isEmulator = androidInfo.isPhysicalDevice == false ||
            androidInfo.model.contains('sdk') ||
            androidInfo.model.contains('emulator') ||
            androidInfo.model.contains('Android SDK');

        AppLogger.i(
            'Android cihaz: ${androidInfo.model}, Emülatör: $_isEmulator');
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;

        // Widget hala ağaçta mı kontrol et
        if (!mounted) return;

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
    // Widget hala ağaçta mı kontrol et
    if (!mounted) return;

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

              // Widget hala ağaçta mı kontrol et
              if (mounted) {
                setState(() {
                  _selectedImage = null; // Fotoğrafı sil
                });
                // Fotoğraf silindiğinde animasyon yap
                _animationController.reset();
                _animationController.forward();
              }
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Bitki Analizi'),
        border: Border(
          bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: BlocConsumer<PlantAnalysisCubit, PlantAnalysisState>(
          listener: (context, state) async {
            if (state.status == AnalysisStatus.success &&
                state.selectedAnalysisResult != null) {
              // Analiz başarılı olduğunda sonuç ekranına geçiş
              final currentAnalysisId = state.selectedAnalysisResult?.id;

              // Eğer _lastNavigatedAnalysisId ile aynıysa, navigation yapma
              if (_lastNavigatedAnalysisId != currentAnalysisId) {
                _lastNavigatedAnalysisId = currentAnalysisId;

                final resultId = state.selectedAnalysisResult!.id;
                AppLogger.i(
                  'Analiz sonuç ekranına geçiş - ID: $resultId, Uzunluk: ${resultId.length}',
                );

                // Navigator'ın mount durumunu kontrol et
                if (mounted && Navigator.of(context).canPop()) {
                  await Navigator.of(context)
                      .push(
                    CupertinoPageRoute(
                      builder: (context) =>
                          AnalysisResultScreen(analysisId: resultId),
                    ),
                  )
                      .then((_) {
                    // Sonuç ekranından dönüldüğünde state'i sıfırla
                    if (mounted) {
                      context.read<PlantAnalysisCubit>().reset();
                      // Navigation ID'sini temizle
                      _lastNavigatedAnalysisId = null;
                    }
                  });
                } else {
                  // Güvenli navigasyon için alternatif yaklaşım
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.of(context, rootNavigator: true)
                          .push(
                        CupertinoPageRoute(
                          builder: (context) =>
                              AnalysisResultScreen(analysisId: resultId),
                        ),
                      )
                          .then((_) {
                        if (mounted) {
                          context.read<PlantAnalysisCubit>().reset();
                          _lastNavigatedAnalysisId = null;
                        }
                      });
                    }
                  });
                }
              }
            } else if (state.errorMessage != null) {
              // Hata durumunda kullanıcıya bilgi ver
              // needsPremium true ise premium satın alma sayfasına yönlendirme seçeneği sunan diyalog göster
              await _showErrorDialog(state.errorMessage!,
                  needsPremium: state.needsPremium);
            }
          },
          builder: (context, state) {
            final bool isAnalyzing = state.isLoading;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Başlık ve açıklama
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bitkiniz Hakkında Bilgi Alın',
                            style: AppTextTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bitkinin net bir fotoğrafını çekin veya yükleyin. Yapay zeka, hastalık durumunu ve öneriler sunacak.',
                            style: AppTextTheme.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Fotoğraf önizleme alanı
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _selectedImage != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Resim Hero animasyonu ile
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            context.dimensions.radiusL),
                                        child: Hero(
                                          tag: 'plantImage',
                                          child: Image.file(
                                            _selectedImage!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        ),
                                      ),
                                      // Resim üstündeki yarı saydam kontrol katmanı - Cupertino uyumlu
                                      GestureDetector(
                                        onTap: isAnalyzing
                                            ? null
                                            : _showImageOptionsMenu,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.center,
                                              colors: [
                                                CupertinoColors.black
                                                    .withOpacity(0.4),
                                                CupertinoColors.transparent,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                                context.dimensions.radiusL),
                                          ),
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                  bottom: context
                                                      .dimensions.paddingM),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: context
                                                      .dimensions.paddingM,
                                                  vertical: context
                                                      .dimensions.paddingXS,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: CupertinoColors.white
                                                      .withOpacity(0.8),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          context.dimensions
                                                              .radiusL),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: CupertinoColors
                                                          .black
                                                          .withOpacity(0.1),
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      CupertinoIcons
                                                          .camera_fill,
                                                      color: AppColors.primary,
                                                      size: context
                                                          .dimensions.iconSizeS,
                                                    ),
                                                    SizedBox(
                                                        width: context
                                                            .dimensions
                                                            .spaceXXS),
                                                    Text(
                                                      'Değiştir',
                                                      style: AppTextTheme
                                                          .captionL
                                                          .copyWith(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: CupertinoColors
                                                            .label,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Bilgi simgesi (sağ üst köşe)
                                      Positioned(
                                        top: context.dimensions.paddingS,
                                        right: context.dimensions.paddingS,
                                        child: Container(
                                          height:
                                              context.dimensions.buttonHeight *
                                                  0.7,
                                          width:
                                              context.dimensions.buttonHeight *
                                                  0.7,
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.white
                                                .withOpacity(0.8),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: CupertinoColors.black
                                                    .withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            CupertinoIcons.info,
                                            color: AppColors.primary,
                                            size: context.dimensions.iconSizeS,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : GestureDetector(
                                    onTap:
                                        isAnalyzing ? null : _showPhotoOptions,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemBackground,
                                        borderRadius: BorderRadius.circular(
                                            context.dimensions.radiusL),
                                        border: Border.all(
                                          color: CupertinoColors.systemGrey5,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: CupertinoColors.systemGrey5
                                                .withOpacity(0.5),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // İçerik
                                          Padding(
                                            padding: EdgeInsets.all(
                                                context.dimensions.paddingL),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                // İkon kısmı
                                                Container(
                                                  width: context.dimensions
                                                          .screenWidth *
                                                      0.25,
                                                  height: context.dimensions
                                                          .screenWidth *
                                                      0.25,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        AppColors.primary
                                                            .withOpacity(0.1),
                                                        AppColors.primary
                                                            .withOpacity(0.05),
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: AppColors.primary
                                                          .withOpacity(0.2),
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    CupertinoIcons.camera,
                                                    color: AppColors.primary,
                                                    size: context
                                                        .dimensions.iconSizeL,
                                                  ),
                                                ),
                                                SizedBox(
                                                    height: context
                                                        .dimensions.spaceM),
                                                Text(
                                                  'Fotoğraf Ekleyin',
                                                  style: AppTextTheme.bodyLarge
                                                      .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(
                                                    height: context
                                                        .dimensions.spaceXS),
                                                Text(
                                                  'Analizin doğru yapılabilmesi için bitkinizin net bir fotoğrafını ekleyin',
                                                  style: AppTextTheme.bodyText2
                                                      .copyWith(
                                                    color: CupertinoColors
                                                        .systemGrey,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Ekleme butonu (sağ alt köşede)
                                          Positioned(
                                            bottom: context.dimensions.paddingM,
                                            right: context.dimensions.paddingM,
                                            child: Container(
                                              height: context
                                                  .dimensions.buttonHeight,
                                              width: context
                                                  .dimensions.buttonHeight,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppColors.primary,
                                                    AppColors.primary
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.primary
                                                        .withOpacity(0.3),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                CupertinoIcons.plus,
                                                color: CupertinoColors.white,
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Konum seçimi (il, ilçe, mahalle)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konum Bilgileri',
                            style: AppTextTheme.captionL.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // İl seçimi
                          GestureDetector(
                            onTap: _showProvinceSelector,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey4,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.map_pin,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'İl',
                                          style: AppTextTheme.caption.copyWith(
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedProvince?.name ?? "İl seçin",
                                          style:
                                              AppTextTheme.bodyText2.copyWith(
                                            color: _selectedProvince == null
                                                ? CupertinoColors.systemGrey
                                                : CupertinoColors.label,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _loadingProvinces
                                      ? const CupertinoActivityIndicator()
                                      : const Icon(
                                          CupertinoIcons.chevron_down,
                                          color: CupertinoColors.systemGrey,
                                          size: 16,
                                        ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // İlçe seçimi
                          GestureDetector(
                            onTap: _showDistrictSelector,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey4,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.location,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'İlçe',
                                          style: AppTextTheme.caption.copyWith(
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedDistrict?.name ??
                                              "İlçe seçin",
                                          style:
                                              AppTextTheme.bodyText2.copyWith(
                                            color: _selectedDistrict == null
                                                ? CupertinoColors.systemGrey
                                                : CupertinoColors.label,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _loadingDistricts
                                      ? const CupertinoActivityIndicator()
                                      : const Icon(
                                          CupertinoIcons.chevron_down,
                                          color: CupertinoColors.systemGrey,
                                          size: 16,
                                        ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Mahalle seçimi
                          GestureDetector(
                            onTap: _showNeighborhoodSelector,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey4,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.location_solid,
                                    color: AppColors.info,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Mahalle',
                                          style: AppTextTheme.caption.copyWith(
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _selectedNeighborhood?.name ??
                                              "Mahalle seçin",
                                          style:
                                              AppTextTheme.bodyText2.copyWith(
                                            color: _selectedNeighborhood == null
                                                ? CupertinoColors.systemGrey
                                                : CupertinoColors.label,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _loadingNeighborhoods
                                      ? const CupertinoActivityIndicator()
                                      : const Icon(
                                          CupertinoIcons.chevron_down,
                                          color: CupertinoColors.systemGrey,
                                          size: 16,
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tarla adı kısmı
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tarla Bilgileri',
                            style: AppTextTheme.captionL.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Tarla seçimi
                          GestureDetector(
                            onTap: _showFieldNameInput,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey4,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.tree,
                                    color: AppColors.success,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tarla Adı',
                                          style: AppTextTheme.caption.copyWith(
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _fieldNameController.text.isEmpty
                                              ? "Tarla adı girin"
                                              : _fieldNameController.text,
                                          style:
                                              AppTextTheme.bodyText2.copyWith(
                                            color: _fieldNameController
                                                    .text.isEmpty
                                                ? CupertinoColors.systemGrey
                                                : CupertinoColors.label,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    CupertinoIcons.chevron_down,
                                    color: CupertinoColors.systemGrey,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Analiz butonu
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: AppButton(
                        text: isAnalyzing ? 'Analiz Ediliyor...' : 'Analiz Et',
                        isLoading: isAnalyzing,
                        onPressed: _selectedImage != null && !isAnalyzing
                            ? _startAnalysis
                            : null,
                        icon: isAnalyzing
                            ? null
                            : CupertinoIcons.leaf_arrow_circlepath,
                        height: 58,
                      ),
                    ),

                    // İpuçları kartı
                    if (_selectedImage != null)
                      AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 500),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.info.withOpacity(0.1),
                                  AppColors.primary.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.info.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.info.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.lightbulb_fill,
                                        color: AppColors.info,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Analiz İpuçları',
                                      style: AppTextTheme.captionL.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.info,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.checkmark_circle_fill,
                                      color: AppColors.info,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Bitkinizin yaprak ve gövdesini net şekilde gösteren fotoğraflar kullanın',
                                        style: AppTextTheme.bodyText2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.checkmark_circle_fill,
                                      color: AppColors.info,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Gün ışığında veya iyi aydınlatma altında çekim yapın',
                                        style: AppTextTheme.bodyText2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.checkmark_circle_fill,
                                      color: AppColors.info,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Hastalık belirtileri varsa, bu bölgelere odaklanın',
                                        style: AppTextTheme.bodyText2,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
