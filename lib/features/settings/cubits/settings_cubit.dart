import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/base/base_cubit.dart';
import 'package:tatarai/core/services/service_locator.dart';
import 'package:tatarai/core/services/firestore/firestore_service.dart';
import 'package:tatarai/core/models/user_model.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tatarai/features/settings/cubits/settings_state.dart';
import 'package:tatarai/core/repositories/auth_repository.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';

/// Ayarlar sayfası için Cubit
/// Kullanıcı bilgileri ve ayarlar yönetimi
///
/// Firestore'u direkt dinleyerek real-time updates alır
class SettingsCubit extends Cubit<SettingsState> {
  final AuthRepository _authRepository;
  final AuthCubit? _authCubit;

  /// Firestore user document'ini dinleyen subscription
  StreamSubscription? _firestoreSubscription;

  /// Constructor
  SettingsCubit({AuthCubit? authCubit})
      : _authCubit = authCubit,
        _authRepository = ServiceLocator.get<AuthRepository>(),
        super(const SettingsState()) {
    // Firestore listener'ını başlat
    _initializeFirestoreListener();
  }

  /// Firestore user document'ini dinlemeye başlar
  void _initializeFirestoreListener() {
    try {
      if (_authCubit != null) {
        final authState = _authCubit!.state;
        if (authState is AuthAuthenticated) {
          AppLogger.i('SettingsCubit: Firestore listener başlatılıyor');

          final firestoreService = ServiceLocator.get<FirestoreService>();

          _firestoreSubscription = firestoreService.firestore
              .collection('users')
              .doc(authState.user.id)
              .snapshots()
              .listen(
            _onFirestoreUserChanged,
            onError: (error) {
              AppLogger.e('SettingsCubit: Firestore listen error: $error');
            },
          );

          AppLogger.i('SettingsCubit: Firestore listener kuruldu');
        }
      }
    } catch (e) {
      AppLogger.e('SettingsCubit: Firestore listener kurulum hatası: $e');
    }
  }

  /// Firestore user document değişikliklerini işler
  void _onFirestoreUserChanged(dynamic snapshot) {
    try {
      if (snapshot.exists) {
        final userData = snapshot.data() as Map<String, dynamic>;
        final updatedUser = UserModel.fromJson(userData);

        AppLogger.i('SettingsCubit: Firestore user güncellendi');
        AppLogger.d(
            'SettingsCubit: Yeni analiz kredileri: ${updatedUser.analysisCredits}');

        // State'i direkt güncelle
        emit(state.copyWith(
          user: updatedUser,
          isLoading: false,
          errorMessage: null,
        ));
      }
    } catch (e) {
      AppLogger.e('SettingsCubit: Firestore user parse hatası: $e');
    }
  }

  /// Kullanıcı verilerini yenile
  Future<void> refreshUserData() async {
    try {
      emit(state.copyWith(isLoading: true, errorMessage: null));

      // AuthCubit'den mevcut kullanıcı verilerini al
      if (_authCubit != null) {
        final authState = _authCubit!.state;
        if (authState is AuthAuthenticated) {
          AppLogger.i(
              'AuthCubit\'den kullanıcı verileri alınıyor: ${authState.user.id}');

          emit(state.copyWith(
            user: authState.user,
            isLoading: false,
          ));

          AppLogger.i('Kullanıcı verileri başarıyla yenilendi');
          return;
        }
      }

      // AuthCubit yoksa veya authenticated değilse repository'den al
      final user = await _authRepository.getCurrentUserData();

      if (user != null) {
        emit(state.copyWith(
          user: user,
          isLoading: false,
        ));

        AppLogger.i(
            'Kullanıcı verileri repository\'den başarıyla alındı: ${user.id}');
      } else {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Kullanıcı bulunamadı',
        ));

        AppLogger.w('Kullanıcı bulunamadı');
      }
    } catch (e) {
      AppLogger.e('Kullanıcı verileri yenileme hatası: $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Kullanıcı bilgileri yüklenirken hata oluştu',
      ));
    }
  }

  /// Hesabı sil
  Future<void> deleteAccount() async {
    try {
      emit(state.copyWith(isLoading: true));

      await _authRepository.deleteAccount();

      // Başarılı sonucu emit et
      emit(state.copyWith(
        isLoading: false,
        successMessage: 'Hesap başarıyla silindi',
      ));

      AppLogger.i('Hesap başarıyla silindi');
    } catch (e) {
      AppLogger.e('Hesap silme hatası: $e');
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Hesap silinirken hata oluştu',
      ));
    }
  }

  /// Mesajları temizle
  void clearMessages() {
    emit(state.copyWith(
      errorMessage: null,
      successMessage: null,
    ));
  }

  /// Test için analiz kredilerini azalt
  Future<void> deductAnalysisCredits(int amount) async {
    if (_authCubit != null) {
      final authState = _authCubit!.state;
      if (authState is AuthAuthenticated) {
        final currentCredits = authState.user.analysisCredits;
        final newCredits = (currentCredits - amount).clamp(0, 999);

        AppLogger.i(
            'SettingsCubit: Test kredi azaltma: $currentCredits -> $newCredits');

        // AuthCubit'te güncelle
        await _authCubit!.updateAnalysisCredits(newCredits);

        AppLogger.i(
            'SettingsCubit: AuthCubit güncellendi, Firestore listener otomatik çalışacak');
      }
    }
  }

  /// Kaynakları temizle
  @override
  Future<void> close() async {
    AppLogger.i('SettingsCubit: Kaynaklar temizleniyor');
    await _firestoreSubscription?.cancel();
    return super.close();
  }
}
