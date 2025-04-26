import 'dart:io';
import 'dart:typed_data';
import 'dart:convert'; // Base64 için eklendi

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/auth/services/auth_service.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';
import 'package:tatarai/features/plant_analysis/services/gemini_service.dart';
import 'package:tatarai/features/plant_analysis/services/plant_analysis_service.dart';

/// Bitki analizi repository sınıfı
/// API, Firestore ve Storage işlemlerini koordine eder
class PlantAnalysisRepository {
  PlantAnalysisRepository({
    GeminiService? geminiService,
    PlantAnalysisService? plantAnalysisService,
    AuthService? authService,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _geminiService = geminiService ?? GeminiService(),
        _plantAnalysisService = plantAnalysisService ?? PlantAnalysisService(),
        _authService = authService ?? AuthService(),
        _firestore = firestore ??
            FirebaseFirestore.instanceFor(
              app: Firebase.app(),
              databaseId: 'tatarai',
            ),
        _storage = storage ?? FirebaseStorage.instance {
    // Loglama için storage bilgilerini yazdır
    AppLogger.i('Firebase Storage bucket: ${_storage.bucket}');
  }

  final GeminiService _geminiService;
  final PlantAnalysisService _plantAnalysisService;
  final AuthService _authService;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// Bitki resmini analiz et - Gemini veya PlantID API kullanarak
  Future<PlantAnalysisResult> analyzeImage(
    File imageFile, {
    bool useGemini = true,
    String? location,
    String? province,
    String? district,
    String? neighborhood,
    String? fieldName,
  }) async {
    try {
      // Önce kullanıcı girişi kontrolü yap
      final userId = _getCurrentUserId();
      if (userId == null) {
        throw Exception('Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
      }

      // Önce görüntüyü storage'a yükle
      final imageUrl = await _uploadImage(imageFile);

      // Varsayılan konum bilgisi - Sonradan dinamik olarak alınacak
      final String locationInfo = location ?? "Tekirdağ/Tatarlı";

      // Varsayılan boş sonuç
      PlantAnalysisResult result = PlantAnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        plantName: 'Analiz Edilemedi',
        probability: 0.0,
        isHealthy: false,
        diseases: [],
        description: 'Analiz sonucu alınamadı.',
        suggestions: ['Lütfen başka bir fotoğraf ile tekrar deneyin.'],
        imageUrl: imageUrl,
        similarImages: [],
        geminiAnalysis: '',
        location: locationInfo,
        fieldName: fieldName,
      );

      if (useGemini) {
        // Gemini AI ile analiz
        final imageBytes = await imageFile.readAsBytes();
        final response = await _plantAnalysisService.analyzePlant(
          imageBytes,
          userId,
          prompt: null,
          location: location,
          province: province,
          district: district,
          neighborhood: neighborhood,
          fieldName: fieldName,
        );

        if (!response.success) {
          // Eğer kredi yoksa veya başka bir hata varsa
          if (response.needsPremium) {
            throw Exception('Premium gerekli: ${response.message}');
          } else {
            throw Exception(response.message);
          }
        }

        // Gemini yanıtını PlantAnalysisResult'a dönüştür
        result = _parseGeminiResponse(
          response.result ?? '',
          imageUrl,
          locationInfo, // Konum bilgisini parsera da geç
          fieldName, // Tarla adını da parsera geç
        );
      }

      // Sonucu kaydet
      final docId = await saveAnalysisResult(result);

      // Kaydedilen belgenin ID'sini set et
      return result.copyWith(id: docId);
    } catch (e) {
      AppLogger.e('Bitki analiz hatası: $e', e);
      rethrow;
    }
  }

  /// Gemini cevabından PlantAnalysisResult oluştur
  PlantAnalysisResult _parseGeminiResponse(
    String geminiResponse,
    String imageUrl,
    String location,
    String? fieldName,
  ) {
    try {
      // Gemini yanıtını parse edecek değişkenler
      String plantName = 'Bilinmeyen Bitki';
      bool isHealthy = true;
      String description = '';
      List<Disease> diseases = [];
      List<String> suggestions = [];
      List<String> interventionMethods = []; // Müdahale yöntemleri
      List<String> agriculturalTips = []; // Tarımsal öneriler
      List<String> regionalInfo = []; // Bölgesel bilgiler
      String? watering;
      String? sunlight;
      String? soil;
      String? climate;
      String? growthStage; // Gelişim aşaması
      int? growthScore; // Gelişim skoru
      String? growthComment; // Gelişim yorumu

      // Yanıtı satır satır analiz et
      final lines = geminiResponse.split('\n');

      // Parse etme işlemine yardımcı olacak değişkenler
      String currentSection = '';

      for (final line in lines) {
        final trimmedLine = line.trim();

        // Boş satırları atla
        if (trimmedLine.isEmpty) continue;

        // Ana başlıkları tanımla
        if (trimmedLine.startsWith('BITKI_ADI:')) {
          currentSection = 'plantName';
          plantName = trimmedLine.substring('BITKI_ADI:'.length).trim();
        } else if (trimmedLine.startsWith('SAGLIK_DURUMU:')) {
          currentSection = 'healthStatus';
          final status = trimmedLine
              .substring('SAGLIK_DURUMU:'.length)
              .trim()
              .toLowerCase();
          isHealthy =
              status.contains('sağlıklı') && !status.contains('sağlıksız');
        } else if (trimmedLine.startsWith('TANIM:')) {
          currentSection = 'description';
          description = trimmedLine.substring('TANIM:'.length).trim();
        } else if (trimmedLine.startsWith('HASTALIKLAR:')) {
          currentSection = 'diseases';
          // Başlığı atlayıp bir sonraki satıra geç
        } else if (trimmedLine.startsWith('MUDAHALE_YONTEMLERI:')) {
          currentSection = 'interventions';
          // Başlığı atlayıp bir sonraki satıra geç
        } else if (trimmedLine.startsWith('TARIMSAL_ONERILER:')) {
          currentSection = 'agriculturalTips';
          // Başlığı atlayıp bir sonraki satıra geç
        } else if (trimmedLine.startsWith('BOLGESEL_BILGILER:')) {
          currentSection = 'regionalInfo';
          // Başlığı atlayıp bir sonraki satıra geç
        } else if (trimmedLine.startsWith('ONERILER:')) {
          currentSection = 'suggestions';
          // Başlığı atlayıp bir sonraki satıra geç
        } else if (trimmedLine.startsWith('SULAMA:')) {
          currentSection = 'watering';
          watering = trimmedLine.substring('SULAMA:'.length).trim();
        } else if (trimmedLine.startsWith('ISIK:')) {
          currentSection = 'sunlight';
          sunlight = trimmedLine.substring('ISIK:'.length).trim();
        } else if (trimmedLine.startsWith('TOPRAK:')) {
          currentSection = 'soil';
          soil = trimmedLine.substring('TOPRAK:'.length).trim();
        } else if (trimmedLine.startsWith('IKLIM:')) {
          currentSection = 'climate';
          climate = trimmedLine.substring('IKLIM:'.length).trim();
        } else if (trimmedLine.startsWith('GELISIM_ASAMASI:')) {
          currentSection = 'growthStage';
          growthStage = trimmedLine.substring('GELISIM_ASAMASI:'.length).trim();
        } else if (trimmedLine.startsWith('GELISIM_SKORU:')) {
          currentSection = 'growthScore';
          final scoreText =
              trimmedLine.substring('GELISIM_SKORU:'.length).trim();
          // Sayısal değeri ayıkla (70/100 veya sadece 70 formatından)
          final scoreRegex = RegExp(r'(\d+)');
          final match = scoreRegex.firstMatch(scoreText);
          if (match != null) {
            growthScore = int.tryParse(match.group(1) ?? '0') ?? 0;
          }
        } else if (trimmedLine.startsWith('GELISIM_YORUMU:')) {
          currentSection = 'growthComment';
          growthComment =
              trimmedLine.substring('GELISIM_YORUMU:'.length).trim();
        }
        // Mevcut bölüme göre içerik ekleme
        else if (currentSection == 'diseases' && trimmedLine.startsWith('-')) {
          final diseaseLine = trimmedLine.substring(1).trim();
          String diseaseName = diseaseLine;
          String diseaseDescription = '';

          // Hastalık adı ve açıklamasını ayır
          if (diseaseLine.contains(':')) {
            final parts = diseaseLine.split(':');
            diseaseName = parts[0].trim();
            diseaseDescription = parts.length > 1 ? parts[1].trim() : '';
          }

          diseases.add(
            Disease(
              name: diseaseName,
              probability: 0.8, // Varsayılan olasılık
              description: diseaseDescription,
            ),
          );
        } else if (currentSection == 'interventions' &&
            trimmedLine.startsWith('-')) {
          // Müdahale yöntemlerini işle
          final intervention = trimmedLine.substring(1).trim();
          if (intervention.isNotEmpty) {
            interventionMethods.add(intervention);
          }
        } else if (currentSection == 'agriculturalTips' &&
            trimmedLine.startsWith('-')) {
          // Tarımsal önerileri işle
          final tip = trimmedLine.substring(1).trim();
          if (tip.isNotEmpty) {
            agriculturalTips.add(tip);
          }
        } else if (currentSection == 'regionalInfo' &&
            trimmedLine.startsWith('-')) {
          // Bölgesel bilgileri işle
          final info = trimmedLine.substring(1).trim();
          if (info.isNotEmpty) {
            regionalInfo.add(info);
          }
        } else if (currentSection == 'suggestions' &&
            trimmedLine.startsWith('-')) {
          // Eski format önerileri işle
          final suggestion = trimmedLine.substring(1).trim();
          if (suggestion.isNotEmpty) {
            suggestions.add(suggestion);
          }
        } else if (currentSection == 'description') {
          // Daha önceki açıklamaya ekleyin (eğer birden fazla satır varsa)
          if (description.isNotEmpty) {
            description += ' $trimmedLine';
          } else {
            description = trimmedLine;
          }
        } else if (currentSection == 'growthComment' && growthComment != null) {
          // Gelişim yorumunu birleştir (birden fazla satır olabilir)
          growthComment += ' $trimmedLine';
        }
      }

      // Öneriler bölümlerini birleştir (müdahale yöntemleri, tarımsal öneriler ve bölgesel bilgiler)
      List<String> allSuggestions = [];

      // Önce müdahale yöntemlerini ekle
      if (interventionMethods.isNotEmpty) {
        allSuggestions.add("MÜDAHALE YÖNTEMLERİ:");
        allSuggestions.addAll(interventionMethods);
      }

      // Sonra tarımsal önerileri ekle
      if (agriculturalTips.isNotEmpty) {
        if (allSuggestions.isNotEmpty) allSuggestions.add(""); // Boşluk ekle
        allSuggestions.add("TARIMSAL ÖNERİLER:");
        allSuggestions.addAll(agriculturalTips);
      }

      // Bölgesel bilgileri ekle
      if (regionalInfo.isNotEmpty) {
        if (allSuggestions.isNotEmpty) allSuggestions.add(""); // Boşluk ekle
        allSuggestions.add("$location İÇİN BÖLGESEL BİLGİLER:");
        allSuggestions.addAll(regionalInfo);
      }

      // Eski format önerileri varsa ekle
      if (suggestions.isNotEmpty) {
        if (allSuggestions.isNotEmpty) allSuggestions.add(""); // Boşluk ekle
        allSuggestions.add("DİĞER ÖNERİLER:");
        allSuggestions.addAll(suggestions);
      }

      // Hiçbir öneri yoksa varsayılan öneri ekle
      if (allSuggestions.isEmpty) {
        allSuggestions.add(
          'Düzenli sulama yapın ve bitkinin ihtiyaçlarına uygun ortam sağlayın.',
        );
      }

      // Açıklama çok uzunsa kısalt
      if (description.length > 500) {
        description = '${description.substring(0, 497)}...';
      }

      // Toprak ve iklim bilgilerini açıklamaya ekle (eğer varsa)
      String fullDescription = description;
      if (soil != null && soil.isNotEmpty) {
        fullDescription += '\n\nToprak Gereksinimleri: $soil';
      }
      if (climate != null && climate.isNotEmpty) {
        fullDescription += '\n\nİklim Gereksinimleri: $climate';
      }

      // Gelişim durumu bilgisini değerlendirme
      // Eğer gelişim skoru yoksa ama gelişim aşaması biliniyorsa, gelişim skorunu tahmin et
      if (growthScore == null && growthStage != null) {
        // Basit bir tahmin algoritması
        final stageLower = growthStage.toLowerCase();
        if (stageLower.contains('olgun') ||
            stageLower.contains('hasat') ||
            stageLower.contains('olgunlaşma')) {
          growthScore = 85;
        } else if (stageLower.contains('çiçek') ||
            stageLower.contains('cicek') ||
            stageLower.contains('meyve')) {
          growthScore = 70;
        } else if (stageLower.contains('büyüme') ||
            stageLower.contains('gelişme') ||
            stageLower.contains('genc')) {
          growthScore = 50;
        } else if (stageLower.contains('fide') ||
            stageLower.contains('çimlenme') ||
            stageLower.contains('yeni')) {
          growthScore = 30;
        } else {
          growthScore = 60; // Varsayılan orta düzey
        }

        AppLogger.i('Gelişim skoru tahmin edildi: $growthScore');
      }

      // Sonuç nesnesini oluştur
      return PlantAnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        plantName: plantName,
        probability: 0.9, // Gemini'den kesin bir olasılık alamıyoruz
        isHealthy: isHealthy,
        diseases: diseases,
        description: fullDescription,
        suggestions: allSuggestions,
        imageUrl: imageUrl,
        similarImages: [], // Gemini benzer görüntü sağlamıyor
        watering: watering,
        sunlight: sunlight,
        geminiAnalysis: geminiResponse, // Tam Gemini yanıtı
        location: location, // Konum bilgisini de ekle
        fieldName: fieldName,
        growthStage: growthStage,
        growthScore: growthScore,
      );
    } catch (e) {
      AppLogger.e('Gemini yanıtını işleme hatası', e);
      // Hata durumunda basit bir sonuç oluştur
      return PlantAnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        plantName: 'Analiz Edilemedi',
        probability: 0.0,
        isHealthy: false,
        diseases: [],
        description:
            'Gemini yanıtı işlenirken bir hata oluştu: $e.\n\nHam yanıt:\n$geminiResponse',
        suggestions: ['Lütfen başka bir fotoğraf ile tekrar deneyin.'],
        imageUrl: imageUrl,
        similarImages: [],
        geminiAnalysis: geminiResponse,
        location: location, // Konum bilgisini de ekle
        fieldName: fieldName,
        growthStage: null,
        growthScore: null,
      );
    }
  }

  /// min fonksiyonu
  int min(int a, int b) => a < b ? a : b;

  /// Mevcut kullanıcı kimliğini al
  String? _getCurrentUserId() {
    final userId = _authService.currentUser?.uid;
    AppLogger.i('Current User ID: $userId');
    return userId;
  }

  /// Görüntüyü Firebase Storage'a yükle
  Future<String> _uploadImage(File imageFile) async {
    try {
      // Firebase Storage kullanarak görüntüyü yükle
      final userId = _getCurrentUserId() ?? 'anonymous';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Düzenli bir klasör yapısı oluştur: analyses/{userId}/{timestamp}.jpg
      final fileName = '$timestamp.jpg';
      final folderPath = 'analyses/$userId';
      final filePath = '$folderPath/$fileName';

      // Referansı oluştur
      final ref = _storage.ref().child(filePath);

      // Görüntüyü sıkıştır
      Uint8List imageBytes;
      int originalSize = await imageFile.length();

      // Eğer dosya büyükse sıkıştır
      if (originalSize > AppConstants.maxImageSizeInBytes) {
        try {
          AppLogger.i(
              'Görüntü sıkıştırılıyor: ${(originalSize / 1024).toStringAsFixed(1)} KB');

          // Dosyayı sıkıştır (kalite AppConstants.imageQuality değeri kullanılarak)
          imageBytes = await FlutterImageCompress.compressWithFile(
                imageFile.absolute.path,
                quality: AppConstants.imageQuality,
                minWidth: 1280,
                minHeight: 1280,
              ) ??
              await imageFile.readAsBytes();

          int compressedSize = imageBytes.length;
          double compressionRatio = (compressedSize / originalSize * 100);
          AppLogger.i(
              'Görüntü sıkıştırıldı: ${(compressedSize / 1024).toStringAsFixed(1)} KB (${compressionRatio.toStringAsFixed(1)}%)');
        } catch (compressError) {
          AppLogger.e('Görüntü sıkıştırma hatası, orijinal dosya kullanılacak',
              compressError);
          imageBytes = await imageFile.readAsBytes();
        }
      } else {
        // Dosya zaten küçükse, direk oku
        AppLogger.i(
            'Görüntü yeterince küçük, sıkıştırma yapılmıyor: ${(originalSize / 1024).toStringAsFixed(1)} KB');
        imageBytes = await imageFile.readAsBytes();
      }

      // Yükleme işlemini başlat
      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'originalSize': originalSize.toString(),
            'compressedSize': imageBytes.length.toString(),
            'uploadDate': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Yükleme tamamlanana kadar bekle ve sonucu al
      final taskSnapshot = await uploadTask;

      // Snapshot'tan URL al - daha güvenilir
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();

      AppLogger.i('Görüntü başarıyla yüklendi: $downloadUrl');
      AppLogger.i('Dosya yolu: $filePath');
      return downloadUrl;

      /* GEÇİCİ ÇÖZÜM: Gerektiğinde base64 formatını kullanabilirsiniz
      AppLogger.i('Firebase Storage devre dışı - base64 formatı kullanılıyor');

      // Dosyayı base64 formatına çevir
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Base64 formatında data URL oluştur
      final imageUrl = 'data:image/jpeg;base64,$base64Image';

      AppLogger.i('Görüntü base64 formatında kodlandı');
      return imageUrl;
      */
    } catch (e) {
      AppLogger.e('Görüntü yükleme hatası (detay): $e', e);

      // Daha açıklayıcı hata mesajı
      if (e.toString().contains('object-not-found')) {
        throw Exception(
            'Dosya yüklendi ancak erişilemedi. Firebase Storage ayarlarınızı kontrol edin.');
      } else if (e.toString().contains('unauthorized')) {
        throw Exception(
            'Kimlik doğrulama hatası: Firebase Storage erişim izni yok.');
      } else if (e.toString().contains('quota-exceeded')) {
        throw Exception('Firebase Storage kotası aşıldı.');
      }

      throw Exception('Görüntü yüklenirken bir hata oluştu: $e');
    }
  }

  /// Analiz sonucunu Firestore'a kaydet
  Future<String> saveAnalysisResult(PlantAnalysisResult result) async {
    try {
      // Belge verileri
      final data = {
        'userId': _authService.currentUser?.uid,
        'plantName': result.plantName,
        'probability': result.probability,
        'isHealthy': result.isHealthy,
        'diseases': result.diseases
            .map((disease) => {
                  'name': disease.name,
                  'probability': disease.probability,
                  'description': disease.description,
                })
            .toList(),
        'description': result.description,
        'suggestions': result.suggestions,
        'imageUrl': result.imageUrl,
        'similarImages': result.similarImages,
        'createdAt': FieldValue.serverTimestamp(),
        'geminiAnalysis': result.geminiAnalysis,
        'sunlight': result.sunlight,
        'water': result.watering,
        'soil': result.soil,
        'climate': result.climate,
        'location': result.location,
        'fieldName': result.fieldName,
        'growthStage': result.growthStage,
        'growthScore': result.growthScore,
      };

      // Firestore'a kaydet
      final docRef = await _firestore
          .collection(AppConstants.analysisCollection)
          .add(data);
      final docId = docRef.id;

      AppLogger.i('Analiz sonucu kaydedildi - Belge ID: $docId');

      return docId; // Belge ID'sini döndür
    } catch (e) {
      AppLogger.e('Analiz sonucu kaydetme hatası: $e', e);
      throw Exception('Analiz sonucu kaydedilirken bir hata oluştu: $e');
    }
  }

  /// Geçmiş analizleri getir
  Future<List<PlantAnalysisResult>> getPastAnalyses() async {
    try {
      // Kullanıcı ID'sini al
      final userId = _getCurrentUserId();
      if (userId == null) {
        throw Exception('Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
      }

      // Kullanıcıya ait analizleri getir
      final snapshot = await _firestore
          .collection(AppConstants.analysisCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      // Belgeleri modele dönüştür
      final analyses = snapshot.docs.map((doc) {
        final data = doc.data();

        // Firestore'dan gelen veriyi modele dönüştür
        final List<dynamic> diseasesData = data['diseases'] ?? [];
        final List<Disease> diseases = diseasesData.map((diseaseData) {
          return Disease(
            name: diseaseData['name'] ?? '',
            probability: diseaseData['probability']?.toDouble() ?? 0.0,
            description: diseaseData['description'],
          );
        }).toList();

        final List<dynamic> suggestionsData = data['suggestions'] ?? [];
        final List<String> suggestions =
            suggestionsData.map((suggestion) => suggestion.toString()).toList();

        // similarImages alanını oku (yoksa boş liste kullan)
        List<String> similarImages = [];
        if (data['similarImages'] != null) {
          similarImages = (data['similarImages'] as List)
              .map((image) => image.toString())
              .toList();
        }

        return PlantAnalysisResult(
          id: doc.id,
          plantName: data['plantName'] ?? 'Bilinmeyen Bitki',
          probability: 1.0, // Kaydedilen analizlerde olasılık saklanmıyor
          isHealthy: data['isHealthy'] ?? true,
          diseases: diseases,
          description: data['description'] ?? '',
          suggestions: suggestions,
          imageUrl: data['imageUrl'] ?? '',
          similarImages: similarImages,
          geminiAnalysis: data['geminiAnalysis'], // Tam Gemini yanıtı
          watering: data['water'],
          sunlight: data['sunlight'],
          location: data['location'],
          fieldName: data['fieldName'],
          growthStage: data['growthStage'],
          growthScore: data['growthScore'],
        );
      }).toList();

      AppLogger.i('${analyses.length} geçmiş analiz bulundu');

      return analyses;
    } catch (e) {
      AppLogger.e('Geçmiş analizleri getirme hatası: $e', e);
      throw Exception('Geçmiş analizler alınırken bir hata oluştu: $e');
    }
  }

  /// Belirli bir analizin detaylarını getir
  Future<PlantAnalysisResult> getAnalysisDetails(String analysisId) async {
    try {
      // Kullanıcı ID'si kontrolü
      final userId = _getCurrentUserId();
      if (userId == null) {
        throw Exception('Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
      }

      AppLogger.i(
        'getAnalysisDetails çağrıldı - ID: $analysisId, Uzunluk: ${analysisId.length}',
      );

      final doc = await _firestore
          .collection(AppConstants.analysisCollection)
          .doc(analysisId)
          .get();

      if (!doc.exists) {
        AppLogger.e('Belge bulunamadı - ID: $analysisId');
        throw Exception('Analiz bulunamadı');
      }

      AppLogger.i('Belge bulundu - ID: $analysisId');

      final data = doc.data()!;

      // Güvenlik kontrolü - sadece kendi verilerine erişebilmeli
      final String docUserId = data['userId'] as String? ?? '';
      AppLogger.i('Belge UserId: $docUserId, Giriş yapan UserId: $userId');

      if (docUserId != userId) {
        AppLogger.e(
          'Erişim reddi - Belge UserId: $docUserId, Giriş yapan UserId: $userId',
        );
        throw Exception('Bu analiz sonucuna erişim yetkiniz bulunmuyor');
      }

      // Veriyi modele dönüştür
      final List<dynamic> diseasesData = data['diseases'] ?? [];
      final List<Disease> diseases = diseasesData.map((diseaseData) {
        return Disease(
          name: diseaseData['name'] ?? '',
          probability: diseaseData['probability']?.toDouble() ?? 0.0,
          description: diseaseData['description'],
        );
      }).toList();

      final List<dynamic> suggestionsData = data['suggestions'] ?? [];
      final List<String> suggestions =
          suggestionsData.map((suggestion) => suggestion.toString()).toList();

      // similarImages alanını oku (yoksa boş liste kullan)
      List<String> similarImages = [];
      if (data['similarImages'] != null) {
        similarImages = (data['similarImages'] as List)
            .map((image) => image.toString())
            .toList();
      }

      return PlantAnalysisResult(
        id: doc.id,
        plantName: data['plantName'] ?? 'Bilinmeyen Bitki',
        probability: 1.0,
        isHealthy: data['isHealthy'] ?? true,
        diseases: diseases,
        description: data['description'] ?? '',
        suggestions: suggestions,
        imageUrl: data['imageUrl'] ?? '',
        similarImages: similarImages,
        geminiAnalysis: data['geminiAnalysis'], // Tam Gemini yanıtı
        watering: data['water'],
        sunlight: data['sunlight'],
        location: data['location'],
        fieldName: data['fieldName'],
        growthStage: data['growthStage'],
        growthScore: data['growthScore'],
      );
    } catch (e) {
      AppLogger.e('Analiz detayları getirme hatası: $e', e);
      throw Exception('Analiz detayları alınırken bir hata oluştu: $e');
    }
  }

  /// Analizleri sil
  Future<void> deleteAnalysis(String analysisId) async {
    try {
      await _firestore
          .collection(AppConstants.analysisCollection)
          .doc(analysisId)
          .delete();

      AppLogger.i('Analiz silindi: $analysisId');
    } catch (e) {
      AppLogger.e('Analiz silme hatası: $e', e);
      throw Exception('Analiz silinirken bir hata oluştu: $e');
    }
  }

  /// Repository metodu - Belirli bir analiz sonucunu getirir
  Future<PlantAnalysisResult?> getAnalysisResult(String id) async {
    try {
      // Kullanıcı ID'sini al
      final userId = _getCurrentUserId();
      if (userId == null) {
        throw Exception('Kullanıcı oturum açmamış');
      }

      AppLogger.i(
        'getAnalysisResult çağrıldı - ID: $id, Uzunluk: ${id.length}',
      );

      // Firestore'dan analiz sonucunu al
      final docRef =
          _firestore.collection(AppConstants.analysisCollection).doc(id);

      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        AppLogger.e('Belge bulunamadı - ID: $id');
        return null;
      }

      AppLogger.i('Belge bulundu - ID: $id');

      // getAnalysisDetails metodunu kullanarak dönüştür
      return getAnalysisDetails(id);
    } catch (e) {
      AppLogger.e('Analiz sonucu getirilirken hata oluştu', e);
      rethrow;
    }
  }

  /// Gemini API'sini kullanarak belirli bir bitkinin bakım önerilerini alır
  Future<String> getPlantCareAdvice(String plantName) async {
    try {
      // Kullanıcı ID'sini al
      final userId = _getCurrentUserId();
      if (userId == null) {
        throw Exception('Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
      }

      // Gemini'den bakım tavsiyesi iste
      final response = await _plantAnalysisService.getPlantCareAdvice(
        plantName,
        userId,
      );

      if (!response.success) {
        if (response.needsPremium) {
          throw Exception('Premium gerekli: ${response.message}');
        } else {
          throw Exception(response.message);
        }
      }

      return response.result ?? 'Bakım önerisi bulunamadı.';
    } catch (e) {
      AppLogger.e('Bakım önerisi hatası: $e', e);
      rethrow;
    }
  }

  /// Gemini API'sini kullanarak belirli bir hastalık için tedavi önerileri alır
  Future<String> getDiseaseRecommendations(String diseaseName) async {
    try {
      // Kullanıcı ID'sini al
      final userId = _getCurrentUserId();
      if (userId == null) {
        throw Exception('Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
      }

      // Gemini'den hastalık önerisi iste
      final response = await _plantAnalysisService.getDiseaseAdvice(
        diseaseName,
        userId,
      );

      if (!response.success) {
        if (response.needsPremium) {
          throw Exception('Premium gerekli: ${response.message}');
        } else {
          throw Exception(response.message);
        }
      }

      return response.result ?? 'Hastalık önerisi bulunamadı.';
    } catch (e) {
      AppLogger.e('Hastalık önerisi hatası: $e', e);
      rethrow;
    }
  }
}
