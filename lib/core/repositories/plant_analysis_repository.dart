import 'dart:io';
import 'dart:typed_data';
// Base64 için eklendi
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:tatarai/core/base/base_repository.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/features/auth/services/auth_service.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';
import 'package:tatarai/features/plant_analysis/services/gemini_service.dart';
import 'package:tatarai/features/plant_analysis/services/plant_analysis_service.dart';

/// Bitki analizi repository sınıfı
/// API, Firestore ve Storage işlemlerini koordine eder
class PlantAnalysisRepository extends BaseRepository {
  PlantAnalysisRepository({
    GeminiService? geminiService,
    PlantAnalysisService? plantAnalysisService,
    AuthService? authService,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _geminiService = geminiService ?? GeminiService(),
        _plantAnalysisService = plantAnalysisService ??
            PlantAnalysisService(
              firestore: firestore ??
                  FirebaseFirestore.instanceFor(
                    app: Firebase.app(),
                    databaseId: 'tatarai',
                  ),
              storage: storage ?? FirebaseStorage.instance,
              authService: authService ?? AuthService(),
            ),
        _authService = authService ?? AuthService(),
        _firestore = firestore ??
            FirebaseFirestore.instanceFor(
              app: Firebase.app(),
              databaseId: 'tatarai',
            ),
        _storage = storage ?? FirebaseStorage.instance {
    logInfo('Firebase Storage bucket: ${_storage.bucket}');
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
    final result = await apiCall<PlantAnalysisResult>(
      operationName: 'Bitki Analizi',
      apiCall: () async {
        // Önce kullanıcı girişi kontrolü yap
        final userId = _getCurrentUserId();
        if (userId == null) {
          throw Exception('Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
        }

        // Önce görüntüyü storage'a yükle
        final imageUrl = await _uploadImage(imageFile);

        // Varsayılan konum bilgisi
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
            locationInfo,
            fieldName,
          );
        }

        // Sonucu kaydet
        final docId = await saveAnalysisResult(result);

        // Kaydedilen belgenin ID'sini set et
        return result.copyWith(id: docId);
      },
    );

    return result ??
        PlantAnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          plantName: 'Analiz Edilemedi',
          probability: 0.0,
          isHealthy: false,
          diseases: [],
          description: 'Analiz sonucu alınamadı.',
          suggestions: ['Lütfen başka bir fotoğraf ile tekrar deneyin.'],
          imageUrl: '',
          similarImages: [],
          geminiAnalysis: '',
          location: location ?? 'Tekirdağ/Tatarlı',
          fieldName: fieldName,
        );
  }

  /// Görüntüyü Firebase Storage'a yükle
  Future<String> _uploadImage(File imageFile) async {
    final result = await storageCall<String>(
      operationName: 'Görüntü Yükleme',
      storageCall: () async {
        final userId = _getCurrentUserId() ?? 'anonymous';
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '$timestamp.jpg';
        final folderPath = 'analyses/$userId';
        final filePath = '$folderPath/$fileName';
        final ref = _storage.ref().child(filePath);

        // Görüntüyü sıkıştır
        Uint8List imageBytes;
        int originalSize = await imageFile.length();

        if (originalSize > AppConstants.maxImageSizeInBytes) {
          try {
            logInfo(
                'Görüntü sıkıştırılıyor: ${(originalSize / 1024).toStringAsFixed(1)} KB');

            imageBytes = await FlutterImageCompress.compressWithFile(
                  imageFile.absolute.path,
                  quality: AppConstants.imageQuality,
                  minWidth: 1280,
                  minHeight: 1280,
                ) ??
                await imageFile.readAsBytes();

            int compressedSize = imageBytes.length;
            double compressionRatio = (compressedSize / originalSize * 100);
            logInfo(
                'Görüntü sıkıştırıldı: ${(compressedSize / 1024).toStringAsFixed(1)} KB (${compressionRatio.toStringAsFixed(1)}%)');
          } catch (compressError) {
            logWarning('Görüntü sıkıştırma hatası, orijinal dosya kullanılacak',
                compressError.toString());
            imageBytes = await imageFile.readAsBytes();
          }
        } else {
          logInfo(
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
        final downloadUrl = await taskSnapshot.ref.getDownloadURL();

        logSuccess('Görüntü yüklendi', 'URL: $downloadUrl, Yol: $filePath');
        return downloadUrl;
      },
    );

    return result ?? '';
  }

  /// Analiz sonucunu Firestore'a kaydet
  Future<String> saveAnalysisResult(PlantAnalysisResult result) async {
    final docId = await storageCall<String>(
      operationName: 'Analiz Sonucu Kaydetme',
      storageCall: () async {
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

        final docRef = await _firestore
            .collection(AppConstants.analysisCollection)
            .add(data);
        final docId = docRef.id;

        logSuccess('Analiz sonucu kaydedildi', 'Belge ID: $docId');
        return docId;
      },
    );

    return docId ?? '';
  }

  /// Geçmiş analizleri getir
  Future<List<PlantAnalysisResult>> getPastAnalyses() async {
    final analyses = await apiCall<List<PlantAnalysisResult>>(
      operationName: 'Geçmiş Analizleri Getirme',
      apiCall: () async {
        final userId = _getCurrentUserId();
        if (userId == null) {
          throw Exception('Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
        }

        final snapshot = await _firestore
            .collection(AppConstants.analysisCollection)
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();

        final analyses = snapshot.docs.map((doc) {
          final data = doc.data();
          final List<dynamic> diseasesData = data['diseases'] ?? [];
          final List<Disease> diseases = diseasesData.map((diseaseData) {
            return Disease(
              name: diseaseData['name'] ?? '',
              probability: diseaseData['probability']?.toDouble() ?? 0.0,
              description: diseaseData['description'],
            );
          }).toList();

          final List<dynamic> suggestionsData = data['suggestions'] ?? [];
          final List<String> suggestions = suggestionsData
              .map((suggestion) => suggestion.toString())
              .toList();

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
            geminiAnalysis: data['geminiAnalysis'],
            watering: data['water'],
            sunlight: data['sunlight'],
            location: data['location'],
            fieldName: data['fieldName'],
            growthStage: data['growthStage'],
            growthScore: data['growthScore'],
          );
        }).toList();

        logSuccess(
            'Geçmiş analizler getirildi', '${analyses.length} analiz bulundu');
        return analyses;
      },
    );

    return analyses ?? [];
  }

  /// Belirli bir analizin detaylarını getir
  Future<PlantAnalysisResult> getAnalysisDetails(String analysisId) async {
    final result = await apiCall<PlantAnalysisResult>(
      operationName: 'Analiz Detaylarını Getirme',
      apiCall: () async {
        final userId = _getCurrentUserId();
        if (userId == null) {
          throw Exception('Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
        }

        logInfo('Analiz detayları getiriliyor', 'ID: $analysisId');

        final doc = await _firestore
            .collection(AppConstants.analysisCollection)
            .doc(analysisId)
            .get();

        if (!doc.exists) {
          throw Exception('Analiz bulunamadı');
        }

        final data = doc.data()!;
        final String docUserId = data['userId'] as String? ?? '';

        if (docUserId != userId) {
          throw Exception('Bu analiz sonucuna erişim yetkiniz bulunmuyor');
        }

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
          geminiAnalysis: data['geminiAnalysis'],
          watering: data['water'],
          sunlight: data['sunlight'],
          location: data['location'],
          fieldName: data['fieldName'],
          growthStage: data['growthStage'],
          growthScore: data['growthScore'],
        );
      },
    );

    return result ??
        PlantAnalysisResult(
          id: analysisId,
          plantName: 'Analiz Bulunamadı',
          probability: 0.0,
          isHealthy: false,
          diseases: [],
          description: 'Analiz detayları alınamadı.',
          suggestions: ['Lütfen daha sonra tekrar deneyin.'],
          imageUrl: '',
          similarImages: [],
          geminiAnalysis: '',
          location: '',
          fieldName: '',
        );
  }

  /// Analizleri sil
  Future<void> deleteAnalysis(String analysisId) async {
    await storageCall<void>(
      operationName: 'Analiz Silme',
      storageCall: () async {
        await _firestore
            .collection(AppConstants.analysisCollection)
            .doc(analysisId)
            .delete();

        logSuccess('Analiz silindi', 'ID: $analysisId');
      },
    );
  }

  /// Belirli bir analiz sonucunu getirir
  Future<PlantAnalysisResult?> getAnalysisResult(String id) async {
    return apiCall<PlantAnalysisResult?>(
      operationName: 'Analiz Sonucu Getirme',
      apiCall: () async {
        final userId = _getCurrentUserId();
        if (userId == null) {
          throw Exception('Kullanıcı oturum açmamış');
        }

        logInfo('Analiz sonucu getiriliyor', 'ID: $id');

        final docRef =
            _firestore.collection(AppConstants.analysisCollection).doc(id);
        final docSnapshot = await docRef.get();

        if (!docSnapshot.exists) {
          logWarning('Analiz bulunamadı', 'ID: $id');
          return null;
        }

        return getAnalysisDetails(id);
      },
    );
  }

  /// Bitkinin bakım önerilerini alır
  Future<String> getPlantCareAdvice(String plantName) async {
    final result = await apiCall<String>(
      operationName: 'Bakım Önerisi Alma',
      apiCall: () async {
        final userId = _getCurrentUserId();
        if (userId == null) {
          throw Exception('Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
        }

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
      },
    );

    return result ?? 'Bakım önerisi alınamadı.';
  }

  /// Hastalık için tedavi önerileri alır
  Future<String> getDiseaseRecommendations(String diseaseName) async {
    final result = await apiCall<String>(
      operationName: 'Hastalık Önerisi Alma',
      apiCall: () async {
        final userId = _getCurrentUserId();
        if (userId == null) {
          throw Exception('Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
        }

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
      },
    );

    return result ?? 'Hastalık önerisi alınamadı.';
  }

  /// Mevcut kullanıcı kimliğini al
  String? _getCurrentUserId() {
    final userId = _authService.currentUser?.uid;
    logInfo('Mevcut kullanıcı ID', userId ?? 'null');
    return userId;
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

        logInfo('Gelişim skoru tahmin edildi: $growthScore');
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
      logError('Gemini yanıtını işleme hatası', e.toString());
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
}
