import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/models/user_model.dart';
import 'package:tatarai/core/repositories/user_repository.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';

/// Profil ekranı için state sınıfı
class ProfileState extends Equatable {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isProfileUpdated;
  final bool isImageUploading;
  final bool isRefreshing;

  const ProfileState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isProfileUpdated = false,
    this.isImageUploading = false,
    this.isRefreshing = false,
  });

  /// Başlangıç state'i
  factory ProfileState.initial() {
    return const ProfileState();
  }

  /// State kopyalama methodu
  ProfileState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool? isProfileUpdated,
    bool? isImageUploading,
    bool? isRefreshing,
  }) {
    return ProfileState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isProfileUpdated: isProfileUpdated ?? this.isProfileUpdated,
      isImageUploading: isImageUploading ?? this.isImageUploading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
        user,
        isLoading,
        errorMessage,
        isProfileUpdated,
        isImageUploading,
        isRefreshing,
      ];
}

/// Profil ekranı işlemlerini yöneten Cubit
class ProfileCubit extends Cubit<ProfileState> {
  final UserRepository _userRepository;
  final AuthCubit? _authCubit;
  StreamSubscription<UserModel?>? _userSubscription;

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

      // Kullanıcıyı dinleme
      _listenUserChanges();
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
      final currentUser = _userRepository.getCurrentUser().then((user) {
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
    try {
      // Mevcut kullanıcı kimliğini al
      final currentUser = await _userRepository.getCurrentUser();
      if (currentUser == null) {
        AppLogger.w('Kullanıcı verisi yenilenemedi: Kullanıcı bulunamadı');
        emit(state.copyWith(
          errorMessage: 'Kullanıcı verisi yenilenemedi: Kullanıcı bulunamadı',
          isRefreshing: false,
        ));
        return;
      }

      emit(state.copyWith(isRefreshing: true, errorMessage: null));
      AppLogger.i('Firestore\'dan kullanıcı verisi yenileniyor...');

      // UserRepository'nin bu metodu Firestore'dan taze veriyi alacak
      final refreshedUser =
          await _userRepository.fetchFreshUserData(currentUser.id);

      if (refreshedUser != null) {
        emit(state.copyWith(
          user: refreshedUser,
          isRefreshing: false,
        ));
        AppLogger.i(
            'Kullanıcı verisi başarıyla yenilendi. Analiz kredisi: ${refreshedUser.analysisCredits}, Rol: ${refreshedUser.role}');
      } else {
        emit(state.copyWith(
          isRefreshing: false,
          errorMessage: 'Kullanıcı verisi yenilenemedi',
        ));
        AppLogger.w('Kullanıcı verisi yenilenemedi');
      }
    } catch (e) {
      AppLogger.e('Kullanıcı verisi yenileme hatası', e);
      emit(state.copyWith(
        isRefreshing: false,
        errorMessage: 'Kullanıcı verisi yenilenirken bir hata oluştu: $e',
      ));
    }
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

  /// Email doğrulama durumunu günceller
  Future<void> refreshEmailVerificationStatus() async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));

      final updatedUser =
          await _userRepository.refreshEmailVerificationStatus();

      if (updatedUser != null) {
        emit(state.copyWith(
          user: updatedUser,
          isLoading: false,
        ));
        AppLogger.i(
            'Profil: Email doğrulama durumu güncellendi: ${updatedUser.isEmailVerified}');
      } else {
        emit(state.copyWith(isLoading: false));
        AppLogger.w('Profil: Email doğrulama durumu güncellenemedi');
      }
    } catch (e) {
      AppLogger.e('Profil: Email doğrulama durumu güncelleme hatası', e);
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Email doğrulama durumu güncellenirken bir hata oluştu',
      ));
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

      emit(state.copyWith(isLoading: false));
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

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}
