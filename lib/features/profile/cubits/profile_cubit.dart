import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/core/repositories/user_repository.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tatarai/core/utils/permission_manager.dart';
import 'package:tatarai/features/profile/cubits/profile_state.dart';

/// Profil ekranı işlemlerini yöneten Cubit
class ProfileCubit extends Cubit<ProfileState> {
  /// Repository instance
  final UserRepository _userRepository;

  /// Auth cubit referansı
  final AuthCubit? _authCubit;

  /// Kullanıcı stream subscription
  StreamSubscription<UserModel?>? _userSubscription;

  /// Auth state stream subscription
  StreamSubscription<User?>? _authStateSubscription;

  /// ImagePicker instance
  final ImagePicker _imagePicker = ImagePicker();

  /// Constructor
  ProfileCubit({
    required UserRepository userRepository,
    AuthCubit? authCubit,
  })  : _userRepository = userRepository,
        _authCubit = authCubit,
        super(ProfileState.initial()) {
    _init();
  }

  /// Cubit başlatma
  void _init() {
    try {
      AppLogger.i('ProfileCubit başlatılıyor');
      _listenUserChanges();
      _listenAuthState();
    } catch (e) {
      AppLogger.e('ProfileCubit başlatma hatası', e);
    }
  }

  /// Kullanıcı değişikliklerini dinleme
  void _listenUserChanges() {
    try {
      // Mevcut kullanıcıyı al
      _getCurrentUser();

      // Kullanıcı değişikliklerini dinle
      _userRepository.getCurrentUser().then((user) {
        if (user != null) {
          _userSubscription?.cancel();
          _userSubscription = _userRepository.getUserStream(user.id).listen(
            (updatedUser) {
              if (updatedUser != null) {
                emit(state.copyWith(
                  user: updatedUser,
                  isLoading: false,
                ));
                AppLogger.i(
                    'Profil: Kullanıcı verisi güncellendi, analiz kredisi: ${updatedUser.analysisCredits}');
              }
            },
            onError: (error) {
              AppLogger.e('Profil: Kullanıcı dinleme hatası', error);
              emit(state.copyWith(
                isLoading: false,
                errorMessage: 'Kullanıcı verisi dinlenirken bir hata oluştu',
              ));
            },
          );
        }
      });
    } catch (e) {
      AppLogger.e('Kullanıcı dinleme başlatma hatası', e);
    }
  }

  /// Mevcut kullanıcıyı getirir
  Future<void> _getCurrentUser() async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));

      final user = await _userRepository.getCurrentUser();

      if (user != null) {
        emit(state.copyWith(
          user: user,
          isLoading: false,
        ));
        AppLogger.i('Profil: Mevcut kullanıcı alındı: ${user.email}');
      } else {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Kullanıcı bilgisi alınamadı',
        ));
        AppLogger.w('Profil: Kullanıcı bilgisi alınamadı');
      }
    } catch (e) {
      AppLogger.e('Profil: Kullanıcı getirme hatası', e);
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Kullanıcı bilgisi alınırken bir hata oluştu',
      ));
    }
  }

  /// Firestore'dan kullanıcı bilgilerini taze olarak yeniden yükler
  Future<void> refreshUserData() async {
    AppLogger.i('ProfileCubit: refreshUserData BAŞLADI.');
    emit(state.copyWith(isRefreshing: true, errorMessage: null));
    try {
      // Mevcut kullanıcı kimliğini al
      final authUser =
          FirebaseAuth.instance.currentUser; // Direkt Auth'tan alalım
      if (authUser == null) {
        AppLogger.w(
            'ProfileCubit: refreshUserData - Kullanıcı oturumu açık değil, işlem durduruldu.');
        emit(state.copyWith(
          errorMessage: 'Kullanıcı oturumu bulunamadı.',
          isRefreshing: false,
          isLoading: false, // isLoading'i de false yapalım
        ));
        return;
      }
      final userId = authUser.uid;
      AppLogger.i(
          'ProfileCubit: refreshUserData - Firestore\'dan kullanıcı verisi ($userId) yenileniyor...');

      // UserRepository'nin bu metodu Firestore'dan taze veriyi alacak
      final refreshedUser = await _userRepository.fetchFreshUserData(userId);

      if (refreshedUser != null) {
        AppLogger.i(
            'ProfileCubit: refreshUserData - Kullanıcı verisi BAŞARIYLA yenilendi. PhotoURL: ${refreshedUser.photoURL}');
        emit(state.copyWith(
          user: refreshedUser,
          isRefreshing: false,
          isLoading: false, // isLoading'i de false yapalım
          errorMessage: null, // Hata mesajını temizle
        ));
        AppLogger.i(
            'ProfileCubit: refreshUserData - Yeni state emit edildi. Analiz kredisi: ${refreshedUser.analysisCredits}, Rol: ${refreshedUser.role}');
      } else {
        AppLogger.w(
            'ProfileCubit: refreshUserData - Kullanıcı verisi yenilenemedi (fetchFreshUserData null döndü).');
        emit(state.copyWith(
          isRefreshing: false,
          isLoading: false, // isLoading'i de false yapalım
          errorMessage: 'Kullanıcı verisi yenilenemedi.',
        ));
      }
    } catch (e, stackTrace) {
      AppLogger.e(
          'ProfileCubit: refreshUserData - Kullanıcı verisi yenileme HATASI!',
          e,
          stackTrace);
      emit(state.copyWith(
        isRefreshing: false,
        isLoading: false, // isLoading'i de false yapalım
        errorMessage: 'Kullanıcı verisi yenilenirken bir hata oluştu: $e',
      ));
    }
    AppLogger.i('ProfileCubit: refreshUserData TAMAMLANDI.');
  }

  /// Kullanıcı profilini günceller
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      emit(state.copyWith(
          isLoading: true, errorMessage: null, isProfileUpdated: false));

      final updatedUser = await _userRepository.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      if (updatedUser != null) {
        emit(state.copyWith(
          user: updatedUser,
          isLoading: false,
          isProfileUpdated: true,
        ));
        AppLogger.i('Profil: Profil güncellendi: ${updatedUser.displayName}');
      } else {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Profil güncellenemedi',
        ));
        AppLogger.w('Profil: Profil güncellenemedi');
      }
    } catch (e) {
      AppLogger.e('Profil: Profil güncelleme hatası', e);
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Profil güncellenirken bir hata oluştu',
      ));
    }
  }

  /// Profil resmi yükleme durumunu günceller
  void setImageUploading(bool isUploading) {
    emit(state.copyWith(isImageUploading: isUploading));
  }

  /// Kullanıcı fotoğrafını günceller ve direk olarak Firestore'daki kullanıcı alanını günceller
  Future<String?> updateUserPhotoAndRefresh(File imageFile) async {
    try {
      AppLogger.i('ProfileCubit: Profil fotoğrafı güncelleme başlatılıyor');
      emit(state.copyWith(isImageUploading: true));

      // Mevcut kullanıcı kontrolü
      final currentUser = state.user;
      if (currentUser == null) {
        throw Exception('Kullanıcı oturum açmamış');
      }

      final userId = currentUser.id;
      AppLogger.i(
          'ProfileCubit: Profil fotoğrafı yükleniyor, User ID: $userId');

      // UserRepository'yi kullanarak profil fotoğrafını işle
      final downloadUrl =
          await _userRepository.processProfilePhoto(imageFile, userId);

      // Kullanıcı verilerini yenile
      if (downloadUrl != null) {
        await refreshUserData();
      }

      // Yükleme durumunu güncelle
      emit(state.copyWith(isImageUploading: false));

      // URL döndür
      return downloadUrl;
    } catch (e) {
      AppLogger.e('ProfileCubit: Genel fotoğraf güncelleme hatası', e);
      emit(state.copyWith(isImageUploading: false));
      rethrow;
    }
  }

  /// Profil fotoğrafını Firebase Storage'a yükler ve Firestore'da günceller
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      AppLogger.i('ProfileCubit: Profil fotoğrafı yükleme başlatılıyor');
      emit(state.copyWith(isImageUploading: true));

      // Dosya kontrolü
      if (!imageFile.existsSync()) {
        AppLogger.e('ProfileCubit: Dosya bulunamadı: ${imageFile.path}');
        throw Exception('Seçilen dosya bulunamadı veya erişilemiyor');
      }

      // Dosya boyutu kontrolü
      final fileSize = await imageFile.length();
      AppLogger.i(
          'ProfileCubit: Dosya boyutu: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      if (fileSize > 5 * 1024 * 1024) {
        // 5MB'dan büyük dosyaları reddet
        AppLogger.e(
            'ProfileCubit: Dosya çok büyük: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        throw Exception(
            'Dosya boyutu çok büyük, lütfen daha küçük bir fotoğraf seçin (maks. 5MB)');
      }

      // Token yenileme
      await refreshAuthToken();

      // Kullanıcı ID kontrolü
      final userId = state.user?.id;
      if (userId == null) {
        throw Exception('Kullanıcı oturum açmamış');
      }

      // UserRepository'yi kullanarak profil fotoğrafını işle
      return await updateUserPhotoAndRefresh(imageFile);
    } catch (e) {
      AppLogger.e('ProfileCubit: Genel fotoğraf yükleme hatası', e);
      emit(state.copyWith(isImageUploading: false));
      rethrow;
    }
  }

  /// Profil fotoğrafını doğrudan Firestore'da günceller (acil/son çare yöntemi)
  Future<bool> updateUserPhotoDirectly(String userId, String photoURL) async {
    try {
      AppLogger.i('ProfileCubit: Doğrudan Firestore photoURL güncelleniyor...');
      AppLogger.i('ProfileCubit: User ID: $userId, Yeni photoURL: $photoURL');

      // UserRepository'yi kullanarak kullanıcı fotoğrafı URL'sini güncelle
      final result = await _userRepository.updateUserPhotoURL(userId, photoURL);

      if (result) {
        AppLogger.i('ProfileCubit: photoURL başarıyla güncellendi');
        await refreshUserData();
      } else {
        AppLogger.e('ProfileCubit: photoURL güncellenemedi');
      }

      return result;
    } catch (e) {
      AppLogger.e('ProfileCubit: Genel güncelleme hatası', e);
      return false;
    }
  }

  /// Firebase Auth durumunu dinler
  void _listenAuthState() {
    try {
      // Firebase doğrudan dinleme
      _authStateSubscription?.cancel();
      _authStateSubscription =
          FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && user.emailVerified) {
          // Eğer email doğrulanmışsa Firestore'daki kullanıcı verisini güncelle
          _updateEmailVerificationInFirestore(user.uid);
        } else if (user == null) {
          // Kullanıcı oturumu kapatmış veya hesabı silinmişse, state'i temizle
          emit(ProfileState.initial());
          AppLogger.i('Auth state değişti: Kullanıcı oturumu kapalı');
        }
      });

      // AuthCubit üzerinden kullanıcı bilgilerini dinle
      _listenToAuthCubit();

      AppLogger.i('Auth state dinleyicisi başlatıldı');
    } catch (e) {
      AppLogger.e('Auth state dinleyicisi başlatma hatası', e);
    }
  }

  /// AuthCubit'i dinleyerek kullanıcı değişikliklerini algılar
  void _listenToAuthCubit() {
    if (_authCubit != null) {
      // AuthCubit'teki kullanıcı değişikliklerini dinle
      _authCubit.stream.listen((authState) {
        if (authState.isAuthenticated && authState.user != null) {
          // Kullanıcı girişi olduğunda profil verilerini güncelle
          if (state.user == null || state.user!.id != authState.user!.id) {
            emit(state.copyWith(user: authState.user));
            AppLogger.i(
                'Profil: AuthCubit üzerinden kullanıcı verileri güncellendi');

            // Firestore'dan tam veriyi almak için yenile
            refreshUserData();
          }
        } else if (!authState.isAuthenticated || authState.user == null) {
          // Kullanıcı çıkış yaptığında state'i temizle
          if (state.user != null) {
            emit(ProfileState.initial());
            AppLogger.i(
                'Profil: AuthCubit üzerinden kullanıcı çıkışı algılandı');
          }
        }

        // Hesap silme durumunu kontrol et
        if (authState.accountDeleted) {
          emit(ProfileState.initial());
          AppLogger.i(
              'Profil: AuthCubit üzerinden hesap silme işlemi algılandı');
          // accountDeleted durumunu temizle
          _authCubit.clearAccountDeletedState();
        }
      });

      AppLogger.i('AuthCubit dinleyicisi başlatıldı');
    }
  }

  /// Firestore'daki kullanıcı verisini güncelleyerek e-posta doğrulama durumunu senkronize eder
  Future<void> _updateEmailVerificationInFirestore(String userId) async {
    try {
      // Önce Firestore'dan güncel kullanıcı verisini al
      final userModel = await _userRepository.fetchFreshUserData(userId);

      // Kullanıcı modeli varsa ve e-posta doğrulanmamış olarak kaydedilmişse
      if (userModel != null && !userModel.isEmailVerified) {
        // Modeli güncelle
        final updatedModel = userModel.copyWith(isEmailVerified: true);

        // Firestore'a kaydet
        await _userRepository.updateUserData(updatedModel);

        // State'i güncelle
        emit(state.copyWith(user: updatedModel));

        AppLogger.i(
            'E-posta doğrulama durumu Firestore\'da güncellendi: $userId');
      }
    } catch (e) {
      AppLogger.e('Firestore e-posta doğrulama güncelleme hatası', e);
    }
  }

  /// Email doğrulama durumunu günceller
  Future<bool> refreshEmailVerificationStatus() async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));

      // Firebase Auth kullanıcısını yenile
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        // Kullanıcıyı yeniden yükle (serverdan güncelle)
        await firebaseUser.reload();

        // Yenilenmiş kullanıcıyı al
        final freshUser = FirebaseAuth.instance.currentUser;

        if (freshUser != null && freshUser.emailVerified) {
          // Eğer e-posta doğrulanmışsa Firestore'daki veriyi güncelle
          await _updateEmailVerificationInFirestore(freshUser.uid);
        }
      }

      // Güncel kullanıcı verisini Firestore'dan al
      final updatedUser =
          await _userRepository.fetchFreshUserData(state.user?.id ?? '');

      if (updatedUser != null) {
        emit(state.copyWith(
          user: updatedUser,
          isLoading: false,
        ));
        AppLogger.i(
            'E-posta doğrulama durumu güncellendi: ${updatedUser.isEmailVerified}');
      } else {
        emit(state.copyWith(isLoading: false));
        AppLogger.w(
            'E-posta doğrulama durumu güncellenemedi: Kullanıcı bulunamadı');
      }

      return updatedUser?.isEmailVerified ?? false;
    } catch (e) {
      AppLogger.e('E-posta doğrulama kontrolü hatası', e);
      emit(state.copyWith(
        isLoading: false,
        errorMessage:
            'E-posta doğrulama durumu kontrol edilirken bir hata oluştu',
      ));
      return false;
    }
  }

  /// Email doğrulama e-postası gönderir
  Future<void> sendEmailVerification() async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));

      await _userRepository.sendEmailVerification();

      emit(state.copyWith(isLoading: false));
      AppLogger.i('Profil: Email doğrulama e-postası gönderildi');
    } catch (e) {
      AppLogger.e('Profil: Email doğrulama e-postası gönderme hatası', e);
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Email doğrulama e-postası gönderilirken bir hata oluştu',
      ));
    }
  }

  /// Hesap silme işlemi (AuthCubit'e iletilir)
  Future<void> deleteAccount() async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));

      if (_authCubit != null) {
        await _authCubit.deleteAccount();
      } else {
        await _userRepository.deleteAccount();
      }

      // Hesap silindikten sonra hemen state'i sıfırla
      emit(ProfileState.initial());
      AppLogger.i('Profil: Hesap silindi');
    } catch (e) {
      AppLogger.e('Profil: Hesap silme hatası', e);
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Hesap silinirken bir hata oluştu',
      ));
    }
  }

  /// Çıkış yapma işlemi (AuthCubit'e iletilir)
  Future<void> signOut() async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));

      if (_authCubit != null) {
        await _authCubit.signOut();
      } else {
        await _userRepository.signOut();
      }

      emit(state.copyWith(isLoading: false));
      AppLogger.i('Profil: Çıkış yapıldı');
    } catch (e) {
      AppLogger.e('Profil: Çıkış yapma hatası', e);
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Çıkış yapılırken bir hata oluştu',
      ));
    }
  }

  /// Kimlik doğrulama tokenını yeniler
  Future<void> refreshAuthToken() async {
    try {
      AppLogger.i('Kimlik doğrulama tokenı yenileniyor...');

      // Firebase Auth'tan mevcut kullanıcıyı al
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // Kullanıcı token'ını yenile
        await currentUser.getIdToken(true);
        AppLogger.i(
            'Kimlik doğrulama tokenı başarıyla yenilendi, userId: ${currentUser.uid}');

        // Kullanıcı verilerini yenile
        await refreshUserData();
      } else {
        AppLogger.w('Token yenilenemedi: Kullanıcı oturum açmamış');
      }
    } catch (e) {
      AppLogger.e('Token yenileme hatası', e.toString());
    }
  }

  /// Profil fotoğrafı yükleme işlemini başlatmadan önce çağrılır
  Future<void> prepareForImageUpload() async {
    try {
      // Önce token'ı yenile
      await refreshAuthToken();

      // Yükleme durumunu güncelle
      setImageUploading(true);
    } catch (e) {
      AppLogger.e('Yükleme hazırlığı hatası', e.toString());
      setImageUploading(false);
    }
  }

  /// Hata ve bilgi mesajlarını temizler
  void clearMessages() {
    emit(state.copyWith(
      errorMessage: null,
      isProfileUpdated: false,
      isImageUploading: false,
      isRefreshing: false,
    ));
  }

  /// Hata mesajları için yardımcı metot
  String getPhotoUploadErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('unauthorized') ||
        errorString.contains('permission')) {
      return 'Yetkilendirme hatası: Fotoğraf yükleme izniniz yok';
    } else if (errorString.contains('canceled')) {
      return 'Yükleme iptal edildi';
    } else if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('internet') ||
        errorString.contains('retry-limit')) {
      return 'İnternet bağlantı hatası, lütfen bağlantınızı kontrol edin';
    } else if (errorString.contains('not found') ||
        errorString.contains('bulunamadı')) {
      return 'Dosya bulunamadı veya erişilemiyor';
    } else if (errorString.contains('big') ||
        errorString.contains('large') ||
        errorString.contains('büyük') ||
        errorString.contains('boyut')) {
      return 'Dosya boyutu çok büyük, lütfen daha küçük bir fotoğraf seçin';
    } else if (errorString.contains('quota')) {
      return 'Depolama kotası aşıldı';
    } else if (errorString.contains('token')) {
      return 'Oturum süresi dolmuş olabilir, lütfen tekrar giriş yapın';
    }

    return 'Fotoğraf yüklenirken bir hata oluştu, lütfen tekrar deneyin';
  }

  /// Kamera veya galeriden profil fotoğrafı seçme işlemi
  Future<File?> pickImage(ImageSource source) async {
    try {
      AppLogger.i(
          'Profil fotoğrafı seçimi başlatılıyor, kaynak: ${source == ImageSource.camera ? 'Kamera' : 'Galeri'}');

      // İzin kontrolü - Platform bazlı
      if (source == ImageSource.camera) {
        final hasPermission = await PermissionManager.requestPermission(
          AppPermissionType.camera,
        );
        if (!hasPermission) {
          AppLogger.w('Kamera izni reddedildi');
          return null;
        }
      } else if (source == ImageSource.gallery && Platform.isAndroid) {
        // Android'de galeri için izin gerekir
        final hasPermission = await PermissionManager.requestPermission(
          AppPermissionType.photos,
        );
        if (!hasPermission) {
          AppLogger.w('Galeri izni reddedildi');
          return null;
        }
      }
      // Not: iOS'ta galeri için izin, image_picker tarafından otomatik olarak yönetilir

      // Görüntü seçici aç
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1024,
        maxHeight: 1024,
        preferredCameraDevice: CameraDevice.front, // Ön kamera tercih edilsin
      );

      if (pickedFile == null) {
        AppLogger.i('Görüntü seçimi iptal edildi');
        return null;
      }

      // Dosya oluştur
      final File imageFile = File(pickedFile.path);
      if (!imageFile.existsSync()) {
        AppLogger.e('Seçilen dosya bulunamadı: ${pickedFile.path}');
        return null;
      }

      return imageFile;
    } catch (e) {
      AppLogger.e('Profil fotoğrafı seçme hatası: ${e.toString()}');
      return null;
    }
  }

  /// E-posta doğrulama durumunu kontrol eder ve günceller
  Future<bool> checkAndUpdateEmailVerificationStatus() async {
    try {
      AppLogger.i('ProfileCubit: E-posta doğrulama durumu kontrol ediliyor');
      emit(state.copyWith(isLoading: true, errorMessage: null));

      // Firebase Auth kullanıcısını yenile ve doğrulama durumunu kontrol et
      final isVerified = await refreshEmailVerificationStatus();

      emit(state.copyWith(isLoading: false));

      return isVerified;
    } catch (e) {
      AppLogger.e('ProfileCubit: E-posta doğrulama kontrolü hatası', e);
      emit(state.copyWith(
          isLoading: false,
          errorMessage:
              'E-posta doğrulama durumu kontrol edilirken bir hata oluştu'));
      return false;
    }
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    _authStateSubscription?.cancel();
    return super.close();
  }
}
