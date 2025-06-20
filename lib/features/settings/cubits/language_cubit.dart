import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tatarai/core/constants/locale_constants.dart';
import 'package:tatarai/core/init/localization/localization_manager.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/settings/cubits/language_state.dart';

/// Dil seçimi işlemlerini yöneten Cubit
/// Apple HIG prensiplerine uygun modern dil değiştirme deneyimi sunar
class LanguageCubit extends Cubit<LanguageState> {
  /// Constructor - başlangıç durumunu ayarla
  LanguageCubit() : super(const LanguageState()) {
    _initializeCurrentLanguage();
  }

  /// Mevcut dil ayarını al ve state'i güncelle
  void _initializeCurrentLanguage() {
    try {
      final currentLocale = LocalizationManager.instance.currentLocale;
      emit(state.copyWith(
        currentLocale: currentLocale,
        isLoading: false,
      ));

      AppLogger.i('Mevcut dil yüklendi: ${currentLocale.languageCode}');
    } catch (e) {
      AppLogger.e('Dil başlatma hatası: $e');
      emit(state.copyWith(
        errorMessage: 'Dil ayarları yüklenirken hata oluştu',
        isLoading: false,
      ));
    }
  }

  /// Dil değiştirme işlemi
  /// [newLocale] - Değiştirilecek yeni dil
  Future<void> changeLanguage(Locale newLocale) async {
    if (state.isLoading) return; // Eş zamanlı işlemleri engelle

    try {
      // Yükleniyor durumuna geç
      emit(state.copyWith(
        isLoading: true,
        errorMessage: null,
      ));

      AppLogger.i('Dil değiştiriliyor: ${newLocale.languageCode}');

      // LocalizationManager ile dil değiştir
      await LocalizationManager.instance.changeLocale(newLocale);

      // Başarılı durumu bildir
      emit(state.copyWith(
        currentLocale: newLocale,
        isLoading: false,
        successMessage: 'language_change_success',
      ));

      AppLogger.i('Dil başarıyla değiştirildi: ${newLocale.languageCode}');

      // Başarı mesajını temizle
      await Future.delayed(const Duration(seconds: 2));
      emit(state.copyWith(successMessage: null));
    } catch (e) {
      AppLogger.e('Dil değiştirme hatası: $e');

      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'language_cubit_change_error',
      ));

      // Hata mesajını temizle
      await Future.delayed(const Duration(seconds: 3));
      emit(state.copyWith(errorMessage: null));
    }
  }

  /// Türkçe dile geçiş
  Future<void> switchToTurkish() async {
    await changeLanguage(LocaleConstants.trLocale);
  }

  /// İngilizce dile geçiş
  Future<void> switchToEnglish() async {
    await changeLanguage(LocaleConstants.enLocale);
  }

  /// Mevcut dilin Türkçe olup olmadığını kontrol et
  bool get isCurrentLanguageTurkish {
    return state.currentLocale.languageCode ==
        LocaleConstants.trLocale.languageCode;
  }

  /// Mevcut dilin İngilizce olup olmadığını kontrol et
  bool get isCurrentLanguageEnglish {
    return state.currentLocale.languageCode ==
        LocaleConstants.enLocale.languageCode;
  }

  /// Desteklenen dillerin listesini al
  List<Locale> get supportedLocales {
    return LocaleConstants.supportedLocales;
  }

  /// Hata mesajını temizle
  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(errorMessage: null));
    }
  }

  /// Başarı mesajını temizle
  void clearSuccess() {
    if (state.successMessage != null) {
      emit(state.copyWith(successMessage: null));
    }
  }

  /// State'i sıfırla
  void reset() {
    _initializeCurrentLanguage();
  }
}
