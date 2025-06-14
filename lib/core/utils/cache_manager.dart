import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/plant_analysis/data/models/plant_analysis_result.dart';

/// Uygulama verilerini önbelleğe almak için kullanılan yardımcı sınıf
class CacheManager {
  /// SharedPreferences anahtarları
  static const String _kAnalysisResultsKey = 'analysisResults';
  static const String _kAnalysisImagesKey = 'analysisImages';
  static const String _kCacheTimestampKey = 'cacheTimestamp';

  /// Önbellek süresi (7 gün - saniye cinsinden)
  static const int _cacheDuration = 7 * 24 * 60 * 60;

  /// Singleton örneği
  static CacheManager? _instance;

  /// SharedPreferences örneği
  late SharedPreferences _prefs;

  /// Singleton factory metodu
  factory CacheManager() => _instance ??= CacheManager._internal();

  /// Private constructor
  CacheManager._internal();

  /// Cache manager'ı başlatır
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _cleanExpiredCache();
  }

  /// Analiz sonucunu önbelleğe alır
  Future<bool> cacheAnalysisResult(PlantAnalysisResult result) async {
    try {
      // Mevcut analiz sonuçlarını al
      final List<PlantAnalysisResult> results =
          await getCachedAnalysisResults();

      // Aynı ID ile bir sonuç varsa güncelle, yoksa ekle
      final index = results.indexWhere((item) => item.id == result.id);
      if (index != -1) {
        results[index] = result;
      } else {
        results.add(result);
      }

      // Sonuçları JSON'a dönüştür ve kaydet
      final List<String> jsonResults =
          results.map((result) => jsonEncode(result.toJson())).toList();

      await _prefs.setStringList(_kAnalysisResultsKey, jsonResults);
      await _updateCacheTimestamp();

      AppLogger.i('Analiz sonucu önbelleğe alındı: ${result.id}');
      return true;
    } catch (e) {
      AppLogger.e('Analiz sonucu önbelleğe alınamadı', e);
      return false;
    }
  }

  /// Önbellekten analiz sonuçlarını alır
  Future<List<PlantAnalysisResult>> getCachedAnalysisResults() async {
    try {
      final List<String>? jsonResults = _prefs.getStringList(
        _kAnalysisResultsKey,
      );

      if (jsonResults == null || jsonResults.isEmpty) {
        return [];
      }

      return jsonResults
          .map((jsonStr) {
            try {
              final Map<String, dynamic> map = jsonDecode(jsonStr);
              return PlantAnalysisResult.fromJson(map);
            } catch (e) {
              AppLogger.e('Analiz sonucu ayrıştırma hatası', e);
              return null;
            }
          })
          .whereType<PlantAnalysisResult>()
          .toList();
    } catch (e) {
      AppLogger.e('Önbellekten analiz sonuçları alınamadı', e);
      return [];
    }
  }

  /// Belirli bir analiz sonucunu ID'ye göre önbellekten alır
  Future<PlantAnalysisResult?> getCachedAnalysisResultById(String id) async {
    try {
      final List<PlantAnalysisResult> results =
          await getCachedAnalysisResults();
      return results.firstWhere(
        (result) => result.id == id,
        orElse: () => throw Exception('Bulunamadı'),
      );
    } catch (e) {
      AppLogger.e('Önbellekten analiz sonucu alınamadı: $id', e);
      return null;
    }
  }

  /// Bitki fotoğrafını önbelleğe alır
  Future<bool> cacheAnalysisImage(
    String analysisId,
    Uint8List imageBytes,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/analysis_images';

      // Dizin yoksa oluştur
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Fotoğrafı kaydet
      final File file = File('$path/$analysisId.jpg');
      await file.writeAsBytes(imageBytes);

      // Önbellekteki fotoğraf yollarını güncelle
      Map<String, String> imageMap = await _getCachedImagePaths();
      imageMap[analysisId] = file.path;
      await _saveCachedImagePaths(imageMap);

      AppLogger.i('Analiz görüntüsü önbelleğe alındı: $analysisId');
      return true;
    } catch (e) {
      AppLogger.e('Analiz görüntüsü önbelleğe alınamadı', e);
      return false;
    }
  }

  /// Önbellekteki bitki fotoğrafını alır
  Future<File?> getCachedAnalysisImage(String analysisId) async {
    try {
      Map<String, String> imageMap = await _getCachedImagePaths();
      final String? path = imageMap[analysisId];

      if (path == null) {
        return null;
      }

      final file = File(path);
      if (await file.exists()) {
        return file;
      }

      return null;
    } catch (e) {
      AppLogger.e('Önbellekten analiz görüntüsü alınamadı: $analysisId', e);
      return null;
    }
  }

  /// Önbellekteki tüm fotoğraf yollarını alır (private)
  Future<Map<String, String>> _getCachedImagePaths() async {
    try {
      final String? jsonStr = _prefs.getString(_kAnalysisImagesKey);

      if (jsonStr == null || jsonStr.isEmpty) {
        return {};
      }

      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return map.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      AppLogger.e('Önbellekten fotoğraf yolları alınamadı', e);
      return {};
    }
  }

  /// Fotoğraf yollarını önbelleğe kaydeder (private)
  Future<void> _saveCachedImagePaths(Map<String, String> imageMap) async {
    try {
      await _prefs.setString(_kAnalysisImagesKey, jsonEncode(imageMap));
    } catch (e) {
      AppLogger.e('Fotoğraf yolları önbelleğe kaydedilemedi', e);
    }
  }

  /// Belirli bir analizi önbellekten siler
  Future<bool> removeAnalysisFromCache(String analysisId) async {
    try {
      // Analiz sonucunu sil
      final List<PlantAnalysisResult> results =
          await getCachedAnalysisResults();
      results.removeWhere((result) => result.id == analysisId);

      final List<String> jsonResults =
          results.map((result) => jsonEncode(result.toJson())).toList();

      await _prefs.setStringList(_kAnalysisResultsKey, jsonResults);

      // Fotoğrafı sil
      Map<String, String> imageMap = await _getCachedImagePaths();
      final String? path = imageMap[analysisId];

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }

        imageMap.remove(analysisId);
        await _saveCachedImagePaths(imageMap);
      }

      AppLogger.i('Analiz önbellekten silindi: $analysisId');
      return true;
    } catch (e) {
      AppLogger.e('Analiz önbellekten silinemedi: $analysisId', e);
      return false;
    }
  }

  /// Tüm önbelleği temizler
  Future<bool> clearCache() async {
    try {
      // Analiz sonuçlarını temizle
      await _prefs.remove(_kAnalysisResultsKey);

      // Fotoğrafları temizle
      Map<String, String> imageMap = await _getCachedImagePaths();

      for (String path in imageMap.values) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await _prefs.remove(_kAnalysisImagesKey);
      await _prefs.remove(_kCacheTimestampKey);

      AppLogger.i('Tüm önbellek temizlendi');
      return true;
    } catch (e) {
      AppLogger.e('Önbellek temizleme hatası', e);
      return false;
    }
  }

  /// Önbellek zaman damgasını günceller (private)
  Future<void> _updateCacheTimestamp() async {
    await _prefs.setInt(
      _kCacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Süresi dolmuş önbelleği temizler (private)
  Future<void> _cleanExpiredCache() async {
    try {
      final int? timestamp = _prefs.getInt(_kCacheTimestampKey);

      if (timestamp == null) {
        return;
      }

      final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (currentTime - timestamp > _cacheDuration) {
        await clearCache();
        AppLogger.i('Süresi dolmuş önbellek temizlendi');
      }
    } catch (e) {
      AppLogger.e('Süresi dolmuş önbellek temizleme hatası', e);
    }
  }
}
