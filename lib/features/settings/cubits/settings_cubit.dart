import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tatarai/core/models/user_model.dart';
import 'package:tatarai/core/repositories/auth_repository.dart';
import 'package:tatarai/core/services/service_locator.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/cubits/auth_cubit.dart';
import 'package:tatarai/features/auth/cubits/auth_state.dart';
import 'package:tatarai/features/settings/cubits/settings_state.dart';

/// Ayarlar sayfası için Cubit
/// Kullanıcı bilgileri ve ayarlar yönetimi
class SettingsCubit extends Cubit<SettingsState> {
  final AuthRepository _authRepository;
  final AuthCubit? _authCubit;

  /// Constructor
  SettingsCubit({AuthCubit? authCubit})
      : _authCubit = authCubit,
        _authRepository = ServiceLocator.get<AuthRepository>(),
        super(const SettingsState());

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
}
