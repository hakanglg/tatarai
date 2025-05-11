import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math; // Math için eklendi
// Base64 için eklendi
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:tatarai/core/base/base_repository.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/services/firebase_manager.dart';
import 'package:tatarai/features/auth/services/auth_service.dart';
import 'package:tatarai/features/plant_analysis/models/plant_analysis_result.dart';
import 'package:tatarai/features/plant_analysis/services/gemini_service.dart';
import 'package:tatarai/features/plant_analysis/services/plant_analysis_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:http/http.dart' as http; // Görüntü indirme için eklendi

/// Bitki analizi repository sınıfı
/// API, Firestore ve Storage işlemlerini koordine eder
class PlantAnalysisRepository extends BaseRepository {
  // Servisler ve yardımcı sınıflar
  final GeminiService _geminiService;
  final PlantAnalysisService _plantAnalysisService;
  final AuthService _authService;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final FirebaseManager _firebaseManager = FirebaseManager();
  bool _isInitialized = false;

  /// Repository constructor'ı
  PlantAnalysisRepository({
    GeminiService? geminiService,
    PlantAnalysisService? plantAnalysisService,
    AuthService? authService,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
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
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance {
    _initialize();
  }

  /// Repository'yi başlat
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // Firebase Manager'ı başlat
      if (!_firebaseManager.isInitialized) {
        await _firebaseManager.initialize();
      }

      AppLogger.i('Firebase Storage bucket: ${_storage.bucket}');
      _isInitialized = true;
      logSuccess('Repository başlatma');
    } catch (e) {
      AppLogger.e('PlantAnalysisRepository başlatma hatası', e);
      // Hata durumunda sessizce devam et, ihtiyaç duyulduğunda yeniden denenecek
    }
  }

  /// Repository'nin başlatıldığından emin ol
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initialize();
    }
  }

  /// Bitkiyi Gemini ile analiz et
  Future<PlantAnalysisResult> analyzeImage({
    required String imageUrl,
    required String location,
    String? fieldName,
  }) async {
    await _ensureInitialized();

    final analysisResult = await _analyzeWithGemini(
      imageUrl,
      location,
      fieldName,
    );

    try {
      await saveAnalysisResult(result: analysisResult);
      return analysisResult;
    } catch (e) {
      logError('Analiz kaydetme hatası', e.toString());
      return analysisResult;
    }
  }

  // URL'den görüntü byte'larını indirmek için yardımcı metot
  // TODO: Gerçek görüntü indirme mantığını implemente et
  Future<Uint8List> _downloadImageBytes(String imageUrl) async {
    try {
      AppLogger.i("URL'den görüntü indiriliyor: $imageUrl");
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        AppLogger.i("$imageUrl adresinden görüntü başarıyla indirildi");
        return response.bodyBytes;
      } else {
        AppLogger.e(
            "$imageUrl adresinden görüntü indirilemedi. Durum kodu: ${response.statusCode}");
        throw Exception('Görüntü indirilemedi');
      }
    } catch (e) {
      AppLogger.e(
          "$imageUrl adresinden görüntü indirilirken hata oluştu: ${e.toString()}");
      throw Exception('Görüntü indirilirken hata oluştu: ${e.toString()}');
    }
  }

  /// Analizi Gemini ile gerçekleştir
  Future<PlantAnalysisResult> _analyzeWithGemini(
      String imageUrl, String location, String? fieldName) async {
    try {
      AppLogger.i("Gemini ile bitki analizi başlatılıyor");

      final userId = _getCurrentUserId();
      if (userId == null) {
        throw Exception('Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
      }

      final String prompt = _createBilingualPrompt(imageUrl, '');
      final Uint8List imageBytes = await _downloadImageBytes(imageUrl);

      if (imageBytes.isEmpty) {
        AppLogger.e("${imageUrl} URL'si için indirilen görüntü byte'ları boş.");
        return PlantAnalysisResult(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            plantName: 'Görüntü İndirilemedi',
            probability: 0.0,
            isHealthy: false,
            diseases: [],
            description: 'Görüntü URL\'den indirilemedi: $imageUrl',
            suggestions: [],
            imageUrl: imageUrl,
            similarImages: [],
            location: location,
            fieldName: fieldName,
            geminiAnalysis: 'Görüntü URL\'den indirilemedi.');
      }

      final response = await _plantAnalysisService.analyzePlant(
        imageBytes,
        userId,
        prompt: prompt,
        location: location,
        fieldName: fieldName,
      );

      if (!response.success) {
        final errorMessage = response.message ?? 'Bilinmeyen hata';
        logError('Gemini analiz hatası', errorMessage);
        return PlantAnalysisResult(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            plantName: 'Analiz Başarısız',
            probability: 0.0,
            isHealthy: false,
            diseases: [],
            description: errorMessage,
            suggestions: [],
            imageUrl: imageUrl,
            similarImages: [],
            location: location,
            fieldName: fieldName,
            geminiAnalysis: response.result ?? errorMessage);
      }

      final result = response.result;
      if (result == null || result.trim().isEmpty) {
        AppLogger.e("Gemini analizi boş sonuç döndü");
        return PlantAnalysisResult(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            plantName: 'Analiz Sonucu Boş',
            probability: 0.0,
            isHealthy: false,
            diseases: [],
            description: 'Gemini analizi boş veya geçersiz bir sonuç döndürdü.',
            suggestions: [],
            imageUrl: imageUrl,
            similarImages: [],
            location: location,
            fieldName: fieldName,
            geminiAnalysis: result ?? 'Boş yanıt');
      }

      AppLogger.i("Gemini analizi başarılı");
      return _parseGeminiResponse(result, imageUrl, location, fieldName);
    } catch (e, stackTrace) {
      final errorMessage = 'Gemini analizi sırasında hata: ${e.toString()}';
      AppLogger.e(errorMessage, e, stackTrace);
      return PlantAnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          plantName: 'Analiz Hatası',
          probability: 0.0,
          isHealthy: false,
          diseases: [],
          description: errorMessage,
          suggestions: [],
          imageUrl: imageUrl,
          similarImages: [],
          location: location,
          fieldName: fieldName,
          geminiAnalysis: errorMessage);
    }
  }

  /// Yedek analiz yöntemi - AI servisi çalışmadığında default yanıt dondürür
  Future<PlantAnalysisResult> _runBackupAnalysis(File imageFile,
      String imageUrl, String location, String? fieldName) async {
    AppLogger.i("Yedek analiz yöntemi çalıştırılıyor");

    try {
      // Basit bir bitkisel analiz sonucu oluştur
      return PlantAnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        plantName: 'Tahmin Edilemiyor',
        probability: 0.5,
        isHealthy: true,
        diseases: [],
        description:
            'API servisi şu anda kullanılamıyor. Görüntünüzü analiz edemedik. '
            'Ancak genel bitki bakım önerilerimiz şunlardır:',
        suggestions: [
          'Düzenli sulama yapın. Toprağın 2-3 cm derinliğindeki kısmı kuruduğunda sulayın.',
          'Yeteri kadar güneş ışığı alan bir yerde tutun.',
          'Bitkinin ihtiyacına göre ayda bir kez organik gübre kullanın.',
          'Sararmış veya kurumuş yaprakları düzenli olarak temizleyin.',
          'Havalandırma yapın ve bitkinizi nemli ortamlarda tutun.',
          'Zararlı böcekler için düzenli kontrol edin.',
        ],
        imageUrl: imageUrl,
        similarImages: [],
        watering: 'Haftada 2-3 kez, toprak kuruduğunda.',
        sunlight: 'Orta derecede güneş ışığı.',
        soil: 'İyi drene olan, besin açısından zengin toprak.',
        climate: 'Ilıman iklimler için uygundur.',
        location: location,
        fieldName: fieldName,
        growthStage: 'Belirlenemedi',
        growthScore: 50,
      );
    } catch (backupError) {
      AppLogger.e("Yedek analiz yöntemi hatası", backupError);

      // Tamamen basit bir sonuç döndür
      return PlantAnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        plantName: 'Analiz Servisi Hatası',
        probability: 0.0,
        isHealthy: false,
        diseases: [],
        description: 'Görsel analiz servisi şu anda kullanılamıyor.',
        suggestions: ['Lütfen daha sonra tekrar deneyin.'],
        imageUrl: imageUrl,
        similarImages: [],
      );
    }
  }

  /// Boş bir analiz sonucu oluşturur
  PlantAnalysisResult _createEmptyAnalysisResult({
    required String imageUrl,
    required String location,
    String? fieldName,
    String? errorMessage,
  }) {
    // PlantAnalysisResult.createEmpty statik metodunu kullan
    return PlantAnalysisResult.createEmpty(
      imageUrl: imageUrl,
      location: location,
      fieldName: fieldName,
      errorMessage: errorMessage,
    );
  }

  /// Görüntüyü Firebase Storage'a yükle
  Future<String> uploadImage(File imageFile) async {
    await _ensureInitialized();

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
        final Uint8List imageBytes = await _compressImageIfNeeded(imageFile);

        // Yükleme işlemini başlat
        final uploadTask = ref.putData(
          imageBytes,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'userId': userId,
              'originalSize': (await imageFile.length()).toString(),
              'compressedSize': imageBytes.length.toString(),
              'uploadDate': DateTime.now().toIso8601String(),
            },
          ),
        );

        // Yükleme tamamlanana kadar bekle ve sonucu al
        final taskSnapshot = await uploadTask;
        final downloadUrl = await taskSnapshot.ref.getDownloadURL();

        AppLogger.i('Görüntü yüklendi', 'URL: $downloadUrl, Yol: $filePath');
        return downloadUrl;
      },
    );

    return result ?? '';
  }

  /// Görüntüyü sıkıştırır eğer gerekiyorsa
  Future<Uint8List> _compressImageIfNeeded(File imageFile) async {
    try {
      int originalSize = await imageFile.length();

      if (originalSize > AppConstants.maxImageSizeInBytes) {
        AppLogger.i(
            'Görüntü sıkıştırılıyor: ${(originalSize / 1024).toStringAsFixed(1)} KB');

        final compressedBytes = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          quality: AppConstants.imageQuality,
          minWidth: 1280,
          minHeight: 1280,
        );

        if (compressedBytes != null) {
          int compressedSize = compressedBytes.length;
          double compressionRatio = (compressedSize / originalSize * 100);
          AppLogger.i(
              'Görüntü sıkıştırıldı: ${(compressedSize / 1024).toStringAsFixed(1)} KB (${compressionRatio.toStringAsFixed(1)}%)');
          return compressedBytes;
        }
      } else {
        AppLogger.i(
            'Görüntü yeterince küçük, sıkıştırma yapılmıyor: ${(originalSize / 1024).toStringAsFixed(1)} KB');
      }

      // Sıkıştırma yapılamadıysa ve gerekli değilse orijinal görüntüyü döndür
      return await imageFile.readAsBytes();
    } catch (e) {
      AppLogger.w('Görüntü sıkıştırma hatası, orijinal dosya kullanılacak',
          e.toString());
      return await imageFile.readAsBytes();
    }
  }

  /// Analiz sonucunu Firestore'a kaydet
  Future<void> saveAnalysisResult({
    required PlantAnalysisResult result,
  }) async {
    await _ensureInitialized();

    await apiCall<void>(
      operationName: 'Analiz Sonucu Kaydetme',
      apiCall: () async {
        final userId = _auth.currentUser?.uid;
        if (userId == null) {
          throw Exception('Kullanıcı oturum açmamış');
        }

        // Yeni hiyerarşik yapı: users/{userId}/analyses/{analysisId}
        final userAnalysesRef = _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .collection(AppConstants.userAnalysesCollection);

        final docRef = result.id.isNotEmpty
            ? userAnalysesRef.doc(result.id)
            : userAnalysesRef.doc();

        // Veriyi Map olarak hazırla
        final Map<String, dynamic> dataToSave =
            _prepareAnalysisDataForSave(result, docRef.id);

        // Verileri kaydet
        await docRef.set(dataToSave);

        AppLogger.i('Analiz sonucu başarıyla kaydedildi: ${docRef.id}');
      },
    );
  }

  /// Analiz sonucunu Firestore için hazırla
  Map<String, dynamic> _prepareAnalysisDataForSave(
      PlantAnalysisResult result, String docId) {
    // PlantAnalysisResult.toJson() metodunu kullanarak doğrudan JSON yapısını oluştur
    final Map<String, dynamic> dataToSave = result.toJson();

    // ID alanını docId ile güncelle
    dataToSave['id'] = docId;

    // Zaman damgasını ekle/güncelle
    dataToSave['timestamp'] = DateTime.now().millisecondsSinceEpoch;

    return dataToSave;
  }

  /// Mevcut kullanıcı kimliğini al
  String? _getCurrentUserId() {
    final userId = _auth.currentUser?.uid;
    AppLogger.i('Mevcut kullanıcı ID', userId ?? 'null');
    return userId;
  }

  /// Kullanıcının geçmiş analizlerini getirir
  Future<List<PlantAnalysisResult>> getPastAnalyses() async {
    await _ensureInitialized();

    return await apiCall<List<PlantAnalysisResult>>(
          operationName: 'Geçmiş Analizleri Getirme',
          apiCall: () async {
            final userId = _auth.currentUser?.uid;
            if (userId == null) {
              throw Exception('Kullanıcı oturum açmamış');
            }

            // Analizleri zaman damgasına göre tersten sırala
            final querySnapshot = await _firestore
                .collection(AppConstants.usersCollection)
                .doc(userId)
                .collection(AppConstants.userAnalysesCollection)
                .orderBy('timestamp', descending: true)
                .get();

            // Sonuçları işle
            return _processAnalysisDocuments(querySnapshot.docs);
          },
          // Hata durumunda boş liste döndür
        ) ??
        [];
  }

  /// Firestore belgelerini analiz sonuçlarına dönüştürür
  List<PlantAnalysisResult> _processAnalysisDocuments(
      List<QueryDocumentSnapshot> docs) {
    final List<PlantAnalysisResult> results = [];

    for (final doc in docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        // Belge ID'sini ekleyelim (eğer yoksa)
        if (!data.containsKey('id') ||
            data['id'] == null ||
            data['id'].toString().isEmpty) {
          data['id'] = doc.id;
        }

        // Belgeyi PlantAnalysisResult nesnesine dönüştür
        final result = _convertDocToAnalysisResult(data, doc.id);
        results.add(result);
      } catch (e) {
        AppLogger.e('Belge işlenirken hata oluştu: ${doc.id}', e.toString());
        // Hataya rağmen diğer belgeleri işlemeye devam et
        continue;
      }
    }

    return results;
  }

  /// Belirli bir analizin detaylarını getir
  Future<PlantAnalysisResult?> getAnalysisDetails(String analysisId) async {
    await _ensureInitialized();

    return await apiCall<PlantAnalysisResult?>(
      operationName: 'Analiz Detayı Getirme',
      apiCall: () async {
        final userId = _auth.currentUser?.uid;
        if (userId == null) {
          throw Exception('Kullanıcı oturum açmamış');
        }

        // Belgeyi getir
        final docSnapshot = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .collection(AppConstants.userAnalysesCollection)
            .doc(analysisId)
            .get();

        if (!docSnapshot.exists) {
          return null;
        }

        // Veriyi al ve ID kontrolü yap
        final data = docSnapshot.data()!;
        if (!data.containsKey('id') ||
            data['id'] == null ||
            data['id'].toString().isEmpty) {
          data['id'] = docSnapshot.id;
        }

        // doğrudan fromJson metodunu kullan
        return PlantAnalysisResult.fromJson(data);
      },
    );
  }

  /// Analizleri sil
  Future<void> deleteAnalysis(String analysisId) async {
    await _ensureInitialized();

    await apiCall<void>(
      operationName: 'Analiz Silme',
      apiCall: () async {
        final userId = _auth.currentUser?.uid;
        if (userId == null) {
          throw Exception('Kullanıcı oturum açmamış');
        }

        // Belgeyi sil
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .collection(AppConstants.userAnalysesCollection)
            .doc(analysisId)
            .delete();

        logSuccess('Analiz silindi', 'Analiz ID: $analysisId');
      },
    );
  }

  /// Belirli bir analiz sonucunu getirir
  Future<PlantAnalysisResult?> getAnalysisResult(String analysisId) async {
    await _ensureInitialized();

    return await apiCall<PlantAnalysisResult?>(
      operationName: 'Analiz Sonucu Getirme',
      apiCall: () async {
        final userId = _auth.currentUser?.uid;
        if (userId == null) {
          throw Exception('Kullanıcı oturum açmamış');
        }

        // Belgeyi getir
        final docSnapshot = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .collection(AppConstants.userAnalysesCollection)
            .doc(analysisId)
            .get();

        if (!docSnapshot.exists) {
          return null;
        }

        // Veriyi al ve _convertDocToAnalysisResult metodunu kullan
        final data = docSnapshot.data()!;
        return _convertDocToAnalysisResult(data, analysisId);
      },
    );
  }

  /// Hata durumunda basitleştirilmiş bir analiz sonucu oluşturur
  PlantAnalysisResult _createSimplifiedErrorResult(
      String analysisId, Map<String, dynamic> data, String errorMessage) {
    return PlantAnalysisResult(
      id: analysisId,
      plantName: 'Bilinmeyen Bitki',
      probability: 0.0,
      isHealthy: true,
      diseases: [],
      description:
          'Analiz sonucu gösterilirken bir hata oluştu. Bu bir örnek analiz sonucudur.',
      suggestions: [
        'Lütfen başka bir analiz seçin veya yeni bir analiz yapın.'
      ],
      imageUrl: data['imageUrl'] ?? '',
      similarImages: [],
    );
  }

  /// Firestore belgesini PlantAnalysisResult nesnesine dönüştürür
  PlantAnalysisResult _convertDocToAnalysisResult(
      Map<String, dynamic> data, String docId) {
    // ID'yi kontrol et ve doküman ID'sini ekle (eğer yoksa)
    if (!data.containsKey('id') ||
        data['id'] == null ||
        data['id'].toString().isEmpty) {
      data['id'] = docId;
    }

    // PlantAnalysisResult.fromJson metodunu kullanarak doğrudan dönüştürme yap
    try {
      return PlantAnalysisResult.fromJson(data);
    } catch (e) {
      String errorDataPreview = data.toString();
      if (errorDataPreview.length > 200) {
        errorDataPreview = errorDataPreview.substring(0, 200) + "...";
      }
      AppLogger.e(
          "PlantAnalysisResult dönüştürme hatası. Hata: ${e.toString()}, Veri: $errorDataPreview");

      // Hata durumunda basitleştirilmiş bir sonuç döndür
      return _createSimplifiedErrorResult(docId, data, e.toString());
    }
  }

  /// Bitkinin bakım önerilerini alır
  Future<String> getPlantCareAdvice(String plantName) async {
    await _ensureInitialized();

    return await apiCall<String>(
          operationName: 'Bakım Önerisi Alma',
          apiCall: () async {
            final userId = _getCurrentUserId();
            if (userId == null) {
              throw Exception(
                  'Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
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
        ) ??
        'Bakım önerisi alınamadı.';
  }

  /// Hastalık için tedavi önerileri alır
  Future<String> getDiseaseRecommendations(String diseaseName) async {
    await _ensureInitialized();

    return await apiCall<String>(
          operationName: 'Hastalık Önerisi Alma',
          apiCall: () async {
            final userId = _getCurrentUserId();
            if (userId == null) {
              throw Exception(
                  'Kullanıcı oturum açmamış. Lütfen önce giriş yapın.');
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
        ) ??
        'Hastalık önerisi alınamadı.';
  }

  /// JSON verisini doğrula ve temizle
  void _validateAndSanitizeJsonData(Map<String, dynamic> jsonData) {
    // Plant name kontrolü
    if (!jsonData.containsKey('plantName') || jsonData['plantName'] == null) {
      AppLogger.w("plantName alanı bulunamadı, varsayılan değer kullanılıyor");
      jsonData['plantName'] = 'Bilinmeyen Bitki';
    }

    // isHealthy kontrolü
    if (!jsonData.containsKey('isHealthy')) {
      AppLogger.w("isHealthy alanı bulunamadı, varsayılan değer kullanılıyor");
      jsonData['isHealthy'] = true;
    }

    // description kontrolü
    if (!jsonData.containsKey('description') ||
        jsonData['description'] == null) {
      AppLogger.w(
          "description alanı bulunamadı, varsayılan değer kullanılıyor");
      jsonData['description'] = 'Açıklama bulunamadı';
    }

    // suggestions kontrolü
    if (!jsonData.containsKey('suggestions') ||
        jsonData['suggestions'] == null) {
      AppLogger.w(
          "suggestions alanı bulunamadı, varsayılan değer kullanılıyor");
      jsonData['suggestions'] = ['Bakım önerisi bulunamadı'];
    } else if (jsonData['suggestions'] is String) {
      // String olarak geldiyse liste olarak dönüştür
      jsonData['suggestions'] = [jsonData['suggestions']];
    }

    // diseases kontrolü
    if (!jsonData.containsKey('diseases') || jsonData['diseases'] == null) {
      AppLogger.w("diseases alanı bulunamadı, varsayılan değer kullanılıyor");
      jsonData['diseases'] = [];

      // Eğer hastalık bilgisi yoksa ve Gemini analiz metni varsa metin analizi yap
      if (jsonData.containsKey('geminiAnalysis') &&
          jsonData['geminiAnalysis'] is String &&
          jsonData['geminiAnalysis'].toString().isNotEmpty) {
        // Metinden hastalık tespiti yap
        _extractDiseasesFromText(jsonData['geminiAnalysis'], jsonData);

        AppLogger.i(
            "Metin analizinden hastalık bilgisi çıkarıldı. Sağlık durumu: ${jsonData['isHealthy']}, Hastalık sayısı: ${(jsonData['diseases'] as List).length}");
      }
    }

    // probability kontrolü
    if (!jsonData.containsKey('probability') ||
        jsonData['probability'] == null) {
      AppLogger.w(
          "probability alanı bulunamadı, varsayılan değer kullanılıyor");
      jsonData['probability'] = 0.5; // Varsayılan değer
    }

    // similarImages kontrolü
    if (!jsonData.containsKey('similarImages') ||
        jsonData['similarImages'] == null) {
      AppLogger.w(
          "similarImages alanı bulunamadı, varsayılan değer kullanılıyor");
      jsonData['similarImages'] = [];
    }

    // Diseases listesini işle ve her bir hastalık için alanları doğrula
    if (jsonData.containsKey('diseases') && jsonData['diseases'] is List) {
      final List<dynamic> diseasesList = jsonData['diseases'];
      for (var diseaseData in diseasesList) {
        if (diseaseData is Map<String, dynamic>) {
          // Her bir hastalık objesi için interventionMethods ve pesticideSuggestions listelerini doğrula
          _convertToList(diseaseData, 'interventionMethods');
          _convertToList(diseaseData, 'pesticideSuggestions');
          // Diğer hastalık alanı kontrolleri buraya eklenebilir (örn: name, description)
          if (!diseaseData.containsKey('name') || diseaseData['name'] == null) {
            diseaseData['name'] = 'Bilinmeyen Hastalık';
          }
          if (!diseaseData.containsKey('description') ||
              diseaseData['description'] == null) {
            diseaseData['description'] = 'Hastalık açıklaması bulunamadı.';
          }
          if (!diseaseData.containsKey('probability') ||
              diseaseData['probability'] == null) {
            diseaseData['probability'] = 0.0;
          }
          if (!diseaseData.containsKey('severity') ||
              diseaseData['severity'] == null) {
            diseaseData['severity'] = 'Belirtilmemiş';
          }
        }
      }
    }

    // Liste dönüşümlerini garantile (genel alanlar için)
    _convertToList(jsonData, 'suggestions');
    _convertToList(jsonData, 'similarImages');
    // _convertToList(jsonData, 'diseases'); // Zaten yukarıda her bir elemanı için yapıldı
    // _convertToList(jsonData, 'interventionMethods'); // Bu, hastalık bazlı, yukarıda işlendi
    _convertToList(jsonData, 'agriculturalTips');
    _convertToList(jsonData, 'regionalInfo');
    _convertToList(jsonData, 'edibleParts');
    _convertToList(jsonData, 'propagationMethods');
  }

  /// Belirtilen alanı liste haline getirir
  void _convertToList(Map<String, dynamic> jsonData, String fieldName) {
    if (jsonData.containsKey(fieldName)) {
      if (jsonData[fieldName] == null) {
        jsonData[fieldName] = [];
      } else if (jsonData[fieldName] is! List) {
        // Liste değilse liste haline dönüştür
        jsonData[fieldName] = [jsonData[fieldName]];
      }
    } else {
      jsonData[fieldName] = [];
    }
  }

  /// Metinden hastalıkları çıkar
  void _extractDiseasesFromText(String text, Map<String, dynamic> target) {
    List<Map<String, dynamic>> diseases = [];
    final lowerText = text.toLowerCase();

    // 1. Önce belirli hastalık adlarını aramaya çalış
    final diseasePatterns = {
      'yaprak yanıklığı': 0.8,
      'kök çürüklüğü': 0.8,
      'külleme': 0.8,
      'pas hastalığı': 0.7,
      'mildiyö': 0.8,
      'antraknoz': 0.8,
      'mozaik virüsü': 0.75,
      'kurşuni küf': 0.7,
      'beyaz sinek': 0.7,
      'yaprak biti': 0.75,
      'kırmızı örümcek': 0.7,
      'fusarium': 0.8,
      'alternaria': 0.8,
      'septoria': 0.8,
      'verticillium': 0.8,
      'bakteriyel solgunluk': 0.8,
      'nematod': 0.7,
      'beslenme eksikliği': 0.6,
      'güneş yanığı': 0.6,
      'su stresi': 0.65,
    };

    // Hastalık belirten terimleri ara
    bool hasAnyDiseaseIndication = lowerText.contains('hastalık') ||
        lowerText.contains('hasar') ||
        lowerText.contains('zarar') ||
        lowerText.contains('enfeksiyon') ||
        lowerText.contains('belirti') ||
        lowerText.contains('çürük') ||
        lowerText.contains('küf') ||
        lowerText.contains('leke') ||
        lowerText.contains('sararmış') ||
        lowerText.contains('solmuş');

    // Hastalık adlarını metin içinde ara
    for (var disease in diseasePatterns.entries) {
      if (lowerText.contains(disease.key)) {
        // Hastalık adının geçtiği cümleyi bul
        int startIdx = lowerText.indexOf(disease.key);

        // Cümlenin başlangıcını bul
        int sentenceStart = lowerText.lastIndexOf('.', startIdx);
        if (sentenceStart < 0) {
          sentenceStart = lowerText.lastIndexOf('\n', startIdx);
        }
        if (sentenceStart < 0) sentenceStart = 0;
        sentenceStart += 1; // Noktayı dahil etme

        // Cümlenin sonunu bul
        int sentenceEnd = lowerText.indexOf('.', startIdx + disease.key.length);
        if (sentenceEnd < 0) {
          sentenceEnd = lowerText.indexOf('\n', startIdx + disease.key.length);
        }
        if (sentenceEnd < 0) sentenceEnd = lowerText.length;

        String description = text.substring(sentenceStart, sentenceEnd).trim();

        // Hastalığa uygun tedavi önerilerini bul
        List<String> treatments = [];
        if (lowerText.contains('tedavi') ||
            lowerText.contains('öneri') ||
            lowerText.contains('müdahale') ||
            lowerText.contains('yapılmalı')) {
          final treatmentRegex = RegExp(
              r'(?:tedavi|öneri|müdahale|yapılmalı)[^\.]*\.',
              caseSensitive: false);
          final treatmentMatches = treatmentRegex.allMatches(lowerText);

          for (var match in treatmentMatches) {
            treatments.add(text.substring(match.start, match.end).trim());
          }
        }

        // Hastalık kapitalize edilmiş adı
        String capitalizedName = disease.key
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');

        diseases.add({
          'name': capitalizedName,
          'probability': disease.value,
          'description': description,
          'treatments': treatments,
        });
      }
    }

    // 2. "Hastalık" kelimesini içeren bölümü ara (eğer belirli hastalıklar bulunamadıysa)
    if (diseases.isEmpty && hasAnyDiseaseIndication) {
      // Hastalık bölümünü bul
      final diseaseSection = RegExp(r'(?:hastalık|enfeksiyon|belirti)[^\n\.]+',
          caseSensitive: false);
      final matches = diseaseSection.allMatches(lowerText);

      for (var match in matches) {
        final content = text.substring(match.start, match.end).trim();

        // Genel bir hastalık girişi oluştur
        diseases.add({
          'name': 'Bitki Hastalığı',
          'probability': 0.7,
          'description': content,
          'treatments': [],
        });
      }
    }

    // 3. Sağlıklı olup olmadığını belirle
    bool isHealthy = true;

    if (diseases.isNotEmpty) {
      isHealthy = false; // Hastalık bulunduysa sağlıksız
    } else if (lowerText.contains('hastalık yok') ||
        lowerText.contains('sağlıklı görünüyor') ||
        lowerText.contains('sağlıklı bir bitki')) {
      isHealthy = true; // Açıkça sağlıklı olduğu belirtildi
    } else if (hasAnyDiseaseIndication) {
      // Hastalık belirtisi var ama spesifik hastalık bulunamadı
      isHealthy = false;
      diseases.add({
        'name': 'Belirsiz Hastalık Belirtileri',
        'probability': 0.6,
        'description':
            'Bitkide hastalık belirtileri görülüyor ancak spesifik bir tanı yapılamadı.',
        'treatments': [
          'Profesyonel bir ziraat mühendisine danışın.',
          'Düzenli gözlem yapın ve değişimleri not edin.',
          'Sulama ve gübreleme rutininizi gözden geçirin.'
        ],
      });
    }

    // Hastalık durumunu ve varsa hastalıkları ekle
    target['isHealthy'] = isHealthy;
    target['diseases'] = diseases;

    AppLogger.i(
        "Hastalık durumu tespit edildi. Sağlıklı: ${target['isHealthy']}, Tespit edilen hastalık sayısı: ${diseases.length}");
  }

  /// Düz metinden veri çıkarma
  Map<String, dynamic> _extractDataFromText(String text) {
    final Map<String, dynamic> data = {};
    final lowerText = text.toLowerCase();

    try {
      // Bitki adını bul
      String? plantName;
      final plantNameRegex = RegExp(
        r'(?:bitki(?:nin)? (?:adı|ismi|türü)|tür(?:ü)?)[:,\s]+([^\n.]+)',
        caseSensitive: false,
      );
      final plantNameMatch = plantNameRegex.firstMatch(lowerText);
      if (plantNameMatch != null && plantNameMatch.group(1) != null) {
        plantName = plantNameMatch.group(1)!.trim();
        // İlk harfi büyük yap
        if (plantName.isNotEmpty) {
          plantName = plantName[0].toUpperCase() + plantName.substring(1);
        }
      }

      // İngilizce yanıt için de kontrol et
      if (plantName == null) {
        final engPlantNameRegex = RegExp(
          r'(?:plant name|plant species|species)[:,\s]+([^\n.]+)',
          caseSensitive: false,
        );
        final engPlantNameMatch =
            engPlantNameRegex.firstMatch(text.toLowerCase());
        if (engPlantNameMatch != null && engPlantNameMatch.group(1) != null) {
          plantName = engPlantNameMatch.group(1)!.trim();
          if (plantName.isNotEmpty) {
            plantName = plantName[0].toUpperCase() + plantName.substring(1);
          }
        }
      }

      data['plantName'] = plantName ?? 'Bilinmeyen Bitki';

      // Açıklama bul
      String? description;
      final descRegex = RegExp(
        r'(?:açıklama|tanım|genel bilgi)[:\s]+([^\n]+)',
        caseSensitive: false,
      );
      final descMatch = descRegex.firstMatch(lowerText);
      if (descMatch != null && descMatch.group(1) != null) {
        description = descMatch.group(1)!.trim();
      }
      data['description'] = description ?? 'Açıklama bulunamadı';

      // Önerileri bul
      List<String> suggestions = [];
      final suggestionRegexList = [
        RegExp(r'(?:öneri(?:ler)?|tavsiye(?:ler)?)[:\s]+([^\n]+)',
            caseSensitive: false),
        RegExp(r'(?:\d+\.)[\s]([^.\n]+)', caseSensitive: false),
        RegExp(r'(?:•|-)[\s]([^•\n]+)', caseSensitive: false),
      ];

      for (var regex in suggestionRegexList) {
        final matches = regex.allMatches(text);
        for (var match in matches) {
          if (match.group(1) != null) {
            final suggestion = match.group(1)!.trim();
            if (suggestion.isNotEmpty && !suggestions.contains(suggestion)) {
              suggestions.add(suggestion);
            }
          }
        }
      }
      data['suggestions'] =
          suggestions.isEmpty ? ['Özel bakım önerisi bulunamadı'] : suggestions;

      // Sulama bilgilerini bul
      String? watering;
      final wateringRegex = RegExp(
        r'(?:sulama)[:\s]+([^\n.]+)',
        caseSensitive: false,
      );
      final wateringMatch = wateringRegex.firstMatch(lowerText);
      if (wateringMatch != null && wateringMatch.group(1) != null) {
        watering = wateringMatch.group(1)!.trim();
      }
      data['watering'] = watering;

      // Işık ihtiyacını bul
      String? sunlight;
      final sunlightRegex = RegExp(
        r'(?:ışık|güneş(?:lenme)?)[:\s]+([^\n.]+)',
        caseSensitive: false,
      );
      final sunlightMatch = sunlightRegex.firstMatch(lowerText);
      if (sunlightMatch != null && sunlightMatch.group(1) != null) {
        sunlight = sunlightMatch.group(1)!.trim();
      }
      data['sunlight'] = sunlight;

      // Toprak ihtiyacını bul
      String? soil;
      final soilRegex = RegExp(
        r'(?:toprak)[:\s]+([^\n.]+)',
        caseSensitive: false,
      );
      final soilMatch = soilRegex.firstMatch(lowerText);
      if (soilMatch != null && soilMatch.group(1) != null) {
        soil = soilMatch.group(1)!.trim();
      }
      data['soil'] = soil;

      // Gelişim aşamasını bul
      String? growthStage;
      final growthStageRegex = RegExp(
        r'(?:gelişim(?:\s+aşaması|\s+dönemi)?|büyüme(?:\s+aşaması)?)[:\s]+([^\n.]+)',
        caseSensitive: false,
      );
      final growthStageMatch = growthStageRegex.firstMatch(lowerText);
      if (growthStageMatch != null && growthStageMatch.group(1) != null) {
        growthStage = growthStageMatch.group(1)!.trim();
      }
      data['growthStage'] = growthStage;

      // Hastalık durumunu ve hastalıkları çıkar
      _extractDiseasesFromText(text, data);

      return data;
    } catch (e) {
      AppLogger.e("Metinden veri çıkarma hatası", e);
      return {};
    }
  }

  /// JSON string'inden yorum satırlarını temizler
  String _cleanJsonComments(String jsonStr) {
    // Yorum satırlarını kaldır - // ile başlayan yorumlar
    final lineRegex = RegExp(r'//.*?$', multiLine: true);
    return jsonStr.replaceAll(lineRegex, '');
  }

  /// Düz metin yanıttan JSON verilerini çıkarma denemeleri
  Map<String, dynamic> _extractJsonFromText(String text) {
    try {
      AppLogger.i(
          "Metin içinden JSON veri çıkarma işlemi başladı. Metin uzunluğu: ${text.length} karakter");

      // 1. Metin içinde { ile başlayıp } ile biten en geniş bloğu bul
      final jsonRegex = RegExp(r'{[\s\S]*}');
      final match = jsonRegex.firstMatch(text);

      if (match != null) {
        final jsonCandidate = match.group(0);
        if (jsonCandidate != null) {
          try {
            final jsonData = json.decode(jsonCandidate);
            if (jsonData is Map<String, dynamic>) {
              AppLogger.i("Metin içinden JSON yapısı başarıyla çıkarıldı");
              return jsonData;
            }
          } catch (e) {
            AppLogger.w(
                "Çıkarılan JSON bloğu ayrıştırılamadı. Hata: ${e.toString()}");
          }
        }
      }

      // 2. JSON çıkarılamadıysa metni semantik olarak analiz et
      return _extractDataFromText(text);
    } catch (e) {
      AppLogger.e("JSON verileri çıkarma hatası", e);
      return {};
    }
  }

  /// İngilizce prompt oluştur ve Türkçe yanıt iste
  String _createBilingualPrompt(String imageUrl, String prompt) {
    // İngilizce analiz promptunu oluştur, Türkçe yanıt iste
    return '''
[PROMPT IN ENGLISH]
Analyze this plant image and provide detailed information about it. Include:
1. Plant species and family.
2. Health assessment (is it healthy or not?).
3. If there are any diseases or issues, identify them with symptoms, severity (Low, Medium, High), and probability.
4. General intervention methods (cultural, biological, physical) for each disease.
5. Specific pesticide or fungicide suggestions (trade names or active ingredients) for each disease.
6. Specific care recommendations for the plant (general, not disease-related).
7. Watering, sunlight, and soil needs for the plant.
8. Growth stage estimation of the plant.
9. Agricultural tips for optimal growth of the plant.

Format the result in well-structured JSON with these fields:
- plantName: (String) The name of the plant.
- description: (String) A brief description of the plant.
- isHealthy: (Boolean) Indicating if the plant is healthy.
- diseases: (Array of Objects) List of identified diseases. Each disease object should contain:
    - name: (String) Name of the disease.
    - probability: (Float) Probability of the disease (0.0 to 1.0).
    - severity: (String) Severity of the disease (e.g., "Low", "Medium", "High").
    - description: (String) Description of the disease symptoms.
    - interventionMethods: (Array of Strings) General intervention methods (non-pesticide).
    - pesticideSuggestions: (Array of Strings) Specific pesticide/fungicide names or active ingredients.
- suggestions: (Array of Strings) General care recommendations for the plant.
- watering: (String) Watering requirements.
- sunlight: (String) Sunlight needs.
- soil: (String) Soil preferences.
- growthStage: (String) Current growth stage of the plant.
- growthScore: (Integer) Numeric assessment of growth (0-100).
- similarImages: (Array of Strings) URLs of similar plant images (can be empty).

[RESPONSE IN TURKISH]
Lütfen yukarıdaki analizi Türkçe olarak yap ve JSON formatında döndür. Hastalıklar için hem genel müdahale yöntemlerini (`interventionMethods`) hem de spesifik pestisit/fungisit önerilerini (`pesticideSuggestions`) ayrı listeler halinde verdiğinden emin ol.
''';
  }

  /// Gemini cevabından PlantAnalysisResult oluştur
  PlantAnalysisResult _parseGeminiResponse(
    String geminiResponse,
    String imageUrl,
    String location,
    String? fieldName,
  ) {
    try {
      final previewLength =
          geminiResponse.length > 100 ? 100 : geminiResponse.length;
      final preview = geminiResponse.substring(0, previewLength);
      AppLogger.i("Gemini yanıtı parse ediliyor. Önizleme: $preview...");

      if (geminiResponse.trim().isEmpty) {
        AppLogger.e("Gemini yanıtı boş geldi");
        return PlantAnalysisResult(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            plantName: 'Boş Yanıt',
            probability: 0.0,
            isHealthy: false,
            diseases: [],
            description: 'Gemini boş yanıt döndürdü.',
            suggestions: [],
            imageUrl: imageUrl,
            similarImages: [],
            location: location,
            fieldName: fieldName,
            geminiAnalysis: geminiResponse);
      }

      AppLogger.i(
          "Gemini ham yanıtı alındı, uzunluk: ${geminiResponse.length}");
      String jsonString = geminiResponse.trim();

      if (jsonString.contains("```json")) {
        final startIndex = jsonString.indexOf("```json") + 7;
        final endIndex = jsonString.lastIndexOf("```");
        if (startIndex > 7 && endIndex > startIndex) {
          jsonString = jsonString.substring(startIndex, endIndex).trim();
          AppLogger.i("Markdown JSON bloğu temizlendi");
        }
      } else if (jsonString.contains("```")) {
        final startIndex = jsonString.indexOf("```") + 3;
        final endIndex = jsonString.lastIndexOf("```");
        if (startIndex > 3 && endIndex > startIndex) {
          jsonString = jsonString.substring(startIndex, endIndex).trim();
          AppLogger.i("Markdown kod bloğu temizlendi");
        }
      }

      jsonString = _cleanJsonComments(jsonString);

      try {
        Map<String, dynamic> jsonData = {};
        try {
          final decoded = json.decode(jsonString);
          if (decoded is Map<String, dynamic>) {
            jsonData = decoded;
            AppLogger.i("Gemini yanıtı JSON olarak başarıyla ayrıştırıldı");
          }
        } catch (jsonDecodeError) {
          AppLogger.w(
              "JSON ayrıştırılamadı. Hata: ${jsonDecodeError.toString()}. Alternatif çözüm yöntemleri deneniyor.");
        }

        if (jsonData.isEmpty) {
          jsonData = _extractJsonFromText(jsonString);
          if (jsonData.isEmpty) {
            jsonData = _extractDataFromText(geminiResponse);
            if (jsonData.isEmpty) {
              AppLogger.w(
                  "Metin işleme başarısız, varsayılan JSON oluşturuluyor");
              jsonData = {
                "plantName": "Bitki Analizi",
                "isHealthy": true,
                "description": "API yanıtı işlenemedi. Ham yanıt:",
                "suggestions": [
                  jsonString.length > 500
                      ? jsonString.substring(0, 500) + "..."
                      : jsonString
                ],
                "diseases": [],
                "interventionMethods": [],
                "agriculturalTips": ["API yanıtı işlenemedi."],
                "watering": "Belirtilmemiş",
                "sunlight": "Belirtilmemiş",
                "soil": "Belirtilmemiş",
                "climate": "Belirtilmemiş",
                "growthStage": "Belirtilmemiş",
                "growthScore": 50
              };
            }
            AppLogger.i("Düz metin yanıt JSON yapısına dönüştürüldü");
          }
        }

        jsonData['id'] = DateTime.now().millisecondsSinceEpoch.toString();
        jsonData['imageUrl'] = imageUrl;
        jsonData['location'] = location;
        jsonData['fieldName'] = fieldName;
        jsonData['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        jsonData['geminiAnalysis'] = geminiResponse;

        _validateAndSanitizeJsonData(jsonData);

        try {
          return PlantAnalysisResult.fromJson(jsonData);
        } catch (fromJsonError) {
          String jsonDataPreview = jsonData.toString();
          if (jsonDataPreview.length > 200) {
            jsonDataPreview = jsonDataPreview.substring(0, 200) + "...";
          }
          AppLogger.e(
              "PlantAnalysisResult.fromJson hatası. Hata: ${fromJsonError.toString()}, JSON: $jsonDataPreview");
          return PlantAnalysisResult(
              id: jsonData['id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              plantName: jsonData['plantName']?.toString() ?? 'fromJson Hatası',
              probability: 0.0,
              isHealthy: false,
              diseases: [],
              description:
                  'JSON dönüştürme hatası: ${fromJsonError.toString()}',
              suggestions: [],
              imageUrl: imageUrl,
              similarImages: [],
              location: location,
              fieldName: fieldName,
              geminiAnalysis: geminiResponse);
        }
      } catch (jsonError) {
        String responsePreview = geminiResponse;
        if (responsePreview.length > 200) {
          responsePreview = responsePreview.substring(0, 200) + "...";
        }
        AppLogger.e(
            "Gemini yanıtını işlemede kritik hata. Hata: ${jsonError.toString()}, Yanıt: $responsePreview");
        return PlantAnalysisResult(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            plantName: 'JSON İşleme Hatası',
            probability: 0.0,
            isHealthy: false,
            diseases: [],
            description: 'Yanıt işleme hatası: ${jsonError.toString()}',
            suggestions: [],
            imageUrl: imageUrl,
            similarImages: [],
            location: location,
            fieldName: fieldName,
            geminiAnalysis: geminiResponse);
      }
    } catch (e, stackTrace) {
      AppLogger.e(
          "Gemini yanıtını parse ederken genel hata oluştu", e, stackTrace);
      if (geminiResponse.length > 1000) {
        AppLogger.e(
            "Uzun yanıt hatası. İlk 500: ${geminiResponse.substring(0, 500)}... Son 500: ${geminiResponse.substring(geminiResponse.length - 500)}");
      } else {
        AppLogger.e("Yanıt içeriği", geminiResponse);
      }
      return PlantAnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          plantName: 'Parse Hatası',
          probability: 0.0,
          isHealthy: false,
          diseases: [],
          description: 'Parse hatası: ${e.toString()}',
          suggestions: [],
          imageUrl: imageUrl,
          similarImages: [],
          location: location,
          fieldName: fieldName,
          geminiAnalysis: geminiResponse);
    }
  }

  /// Kullanıcının analizlerini gerçek zamanlı olarak dinle
  Stream<List<PlantAnalysisResult>> streamUserAnalyses() {
    final userId = _getCurrentUserId();
    if (userId == null) {
      // Kullanıcı giriş yapmamışsa boş liste döndür
      return Stream.value([]);
    }

    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.userAnalysesCollection)
        .orderBy('timestamp', descending: true)
        .limit(10) // Son 10 analizi al
        .snapshots()
        .map((snapshot) {
      final results = <PlantAnalysisResult>[];
      for (final doc in snapshot.docs) {
        try {
          // _convertDocToAnalysisResult metodunu doğrudan kullan
          results.add(_convertDocToAnalysisResult(doc.data(), doc.id));
        } catch (e) {
          AppLogger.e(
              "Analiz sonucu dönüştürme hatası. Hata: ${e.toString()}, Belge ID: ${doc.id}");
          // Hata durumunda basitleştirilmiş bir sonuç ekle
          try {
            results.add(
                _createSimplifiedErrorResult(doc.id, doc.data(), e.toString()));
          } catch (innerError) {
            AppLogger.e(
                "Basitleştirilmiş analiz sonucu oluşturulamadı. Hata: ${innerError.toString()}, Belge ID: ${doc.id}");
          }
        }
      }
      AppLogger.i("Stream analizler güncellendi. Sayı: ${results.length}");
      return results;
    });
  }
}
