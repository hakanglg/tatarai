import 'dart:io';
import 'dart:typed_data';
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
    await _ensureInitialized();

    // 1. Temel loglamayı yap
    logInfo('Bitki analizi başlatılıyor',
        'Dosya: ${imageFile.path}, Boyut: ${await imageFile.length()} bayt');

    try {
      // 2. Kullanıcı kontrolü
      final userId = _getCurrentUserId();
      if (userId == null) {
        logError('Kullanıcı oturum açmamış');
        return PlantAnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          plantName: 'Analiz Edilemedi',
          probability: 0.0,
          isHealthy: false,
          diseases: [],
          description: 'Kullanıcı oturum açmamış.',
          suggestions: ['Lütfen önce giriş yapın.'],
          imageUrl: '',
          similarImages: [],
        );
      }
      logInfo('Kullanıcı kimliği doğrulandı', 'UserID: $userId');

      // 3. Görüntüyü yükle - doğrudan _storage kullanarak
      logInfo('Görüntü yükleniyor', 'Dosya: ${imageFile.path}');

      String imageUrl = '';
      try {
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
        imageUrl = await taskSnapshot.ref.getDownloadURL();
        AppLogger.i('Görüntü yüklendi', 'URL: $imageUrl, Yol: $filePath');
      } catch (uploadError) {
        logError('Görüntü yükleme hatası', uploadError.toString());
        return PlantAnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          plantName: 'Analiz Edilemedi',
          probability: 0.0,
          isHealthy: false,
          diseases: [],
          description: 'Görüntü yüklenirken bir hata oluştu.',
          suggestions: [
            'Lütfen başka bir fotoğraf ile tekrar deneyin.',
            'Hata: ${uploadError.toString()}'
          ],
          imageUrl: '',
          similarImages: [],
        );
      }

      if (imageUrl.isEmpty) {
        logError('Görüntü yüklenemedi');
        return PlantAnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          plantName: 'Analiz Edilemedi',
          probability: 0.0,
          isHealthy: false,
          diseases: [],
          description: 'Görüntü yüklenemedi.',
          suggestions: ['Lütfen başka bir fotoğraf ile tekrar deneyin.'],
          imageUrl: '',
          similarImages: [],
        );
      }
      logSuccess('Görüntü yüklendi', 'URL: $imageUrl');

      // 4. Varsayılan değerleri hazırla
      final String locationInfo = location ?? "Tekirdağ/Tatarlı";
      PlantAnalysisResult result = _createEmptyAnalysisResult(
        imageUrl: imageUrl,
        location: locationInfo,
        fieldName: fieldName,
      );

      if (useGemini) {
        try {
          // 5. Görüntüyü analiz et
          logInfo('Görüntü analizi başlatılıyor', 'Gemini API kullanılıyor');
          final imageBytes = await imageFile.readAsBytes();

          try {
            // Direk PlantAnalysisService üzerinden çağrı yap
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
                logWarning('Premium gerekli', response.message);
                return PlantAnalysisResult(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  plantName: 'Premium Gerekli',
                  probability: 0.0,
                  isHealthy: false,
                  diseases: [],
                  description: 'Bu özellik premium üyelik gerektirir.',
                  suggestions: ['Lütfen üyelik planınızı yükseltin.'],
                  imageUrl: imageUrl,
                  similarImages: [],
                );
              } else {
                logError('Gemini yanıtı başarısız', response.message);
                logInfo('Alternatif analiz denenecek');

                // İlk yöntem başarısız oldu, yedek yöntemi dene
                return await _runBackupAnalysis(
                    imageFile, imageUrl, locationInfo, fieldName);
              }
            }

            // 6. Yanıtı kontrol et
            final responseText = response.result ?? '';
            if (responseText.isEmpty) {
              logError('Gemini yanıtı boş');
              logInfo('Alternatif analiz denenecek');

              // İlk yöntem başarısız oldu, yedek yöntemi dene
              return await _runBackupAnalysis(
                  imageFile, imageUrl, locationInfo, fieldName);
            }
            logSuccess('Gemini yanıtı alındı',
                'Yanıt uzunluğu: ${responseText.length} karakter');

            // 7. Yanıtı işle
            try {
              result = _parseGeminiResponse(
                responseText,
                imageUrl,
                locationInfo,
                fieldName,
              );
              logSuccess('Gemini yanıtı işlendi', 'Bitki: ${result.plantName}');
            } catch (parseError) {
              logError('Gemini yanıtı işleme hatası', parseError.toString());
              // Parse hatası durumunda yedek yöntem yerine ham yanıtı kullan
              return PlantAnalysisResult(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                plantName: 'İşleme Hatası',
                probability: 0.0,
                isHealthy: true,
                diseases: [],
                description:
                    'Analiz sonucu işlenirken bir hata oluştu, ancak ham yanıt aşağıdadır:',
                suggestions: [
                  responseText.length > 1000
                      ? responseText.substring(0, 1000) + "..."
                      : responseText
                ],
                imageUrl: imageUrl,
                similarImages: [],
                geminiAnalysis: responseText,
              );
            }
          } catch (serviceError) {
            logError('Servis hatası', serviceError.toString());
            logInfo('Alternatif analiz denenecek');

            // Service çağrısı başarısız oldu, yedek yöntemi dene
            return await _runBackupAnalysis(
                imageFile, imageUrl, locationInfo, fieldName);
          }
        } catch (analysisError) {
          logError('Gemini analizi hatası', analysisError.toString());
          // Analiz hatası durumunda da yedek yöntemi dene
          return await _runBackupAnalysis(
              imageFile, imageUrl, locationInfo, fieldName);
        }
      }

      // 8. Analiz sonucunu kaydet
      try {
        logInfo('Analiz sonucunu kaydediyor');
        await saveAnalysisResult(result: result);
        logSuccess('Analiz sonucu kaydedildi', 'ID: ${result.id}');
      } catch (saveError) {
        logError('Analiz sonucu kaydetme hatası', saveError.toString());
        // Kayıt hatası olsa bile analiz sonucunu dön
      }

      // 9. Sonucu döndür
      return result;
    } catch (error) {
      logError('Analiz sırasında hata oluştu', 'Hata: ${error.toString()}');

      // Hatanın içeriğinden bölüm gösteren bir yapıyla logu zenginleştir
      String errorDetails = '';
      try {
        errorDetails = error.toString().substring(
            0, error.toString().length > 500 ? 500 : error.toString().length);
      } catch (_) {
        errorDetails = error.toString();
      }
      logError('Hata detayları', errorDetails);

      // Hata ile bir sonuç oluştur - bu aşamada hatayı üst katmana gönderme
      return PlantAnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        plantName: 'Analiz Edilemedi',
        probability: 0.0,
        isHealthy: false,
        diseases: [],
        description: 'Analiz sırasında bir hata oluştu: ${error.toString()}',
        suggestions: [
          'Lütfen başka bir fotoğraf ile tekrar deneyin.',
          'Hata: ${errorDetails}'
        ],
        imageUrl: '',
        similarImages: [],
      );
    }
  }

  /// Yedek analiz yöntemi - AI servisi çalışmadığında default yanıt dondürür
  Future<PlantAnalysisResult> _runBackupAnalysis(File imageFile,
      String imageUrl, String location, String? fieldName) async {
    logInfo('Yedek analiz yöntemi çalıştırılıyor');

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
      logError('Yedek analiz yöntemi hatası', backupError.toString());

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
  }) {
    return PlantAnalysisResult(
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
      location: location,
      fieldName: fieldName,
    );
  }

  /// Görüntüyü Firebase Storage'a yükle
  Future<String> _uploadImage(File imageFile) async {
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

      // Sıkıştırma yapılamadıysa veya gerekli değilse orijinal görüntüyü döndür
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
    final Map<String, dynamic> dataToSave = {
      'id': docId,
      'plantName': result.plantName,
      'probability': result.probability,
      'isHealthy': result.isHealthy,
      'description': result.description,
      'imageUrl': result.imageUrl,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      // Primitive tipler ve basit listeler
      'suggestions': result.suggestions.map((s) => s.toString()).toList(),
      'similarImages': result.similarImages.map((s) => s.toString()).toList(),
      // Diğer alanlar
      'watering': result.watering,
      'sunlight': result.sunlight,
      'soil': result.soil,
      'climate': result.climate,
      'location': result.location,
      'fieldName': result.fieldName,
      'growthStage': result.growthStage,
      'growthScore': result.growthScore,
    };

    // Diseases listesini hazırla
    if (result.diseases.isNotEmpty) {
      dataToSave['diseases'] = result.diseases
          .map((disease) => {
                'name': disease.name,
                'probability': disease.probability,
                'description': disease.description,
              })
          .toList();
    } else {
      dataToSave['diseases'] = [];
    }

    // Gemini analizini ekle (eğer varsa)
    if (result.geminiAnalysis != null && result.geminiAnalysis!.isNotEmpty) {
      dataToSave['geminiAnalysis'] = result.geminiAnalysis;
    }

    // Taksonomi bilgisini ekle (eğer varsa)
    if (result.taxonomy != null) {
      dataToSave['taxonomy'] = {
        'kingdom': result.taxonomy!.kingdom,
        'phylum': result.taxonomy!.phylum,
        'class': result.taxonomy!.class_,
        'order': result.taxonomy!.order,
        'family': result.taxonomy!.family,
        'genus': result.taxonomy!.genus,
        'species': result.taxonomy!.species,
      };
    }

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

        final data = docSnapshot.data()!;
        // Belge ID'sini ekleyelim (eğer yoksa)
        if (!data.containsKey('id') ||
            data['id'] == null ||
            data['id'].toString().isEmpty) {
          data['id'] = docSnapshot.id;
        }

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

        try {
          final data = docSnapshot.data()!;
          // Belge ID'sini ekleyelim (eğer yoksa)
          if (!data.containsKey('id') ||
              data['id'] == null ||
              data['id'].toString().isEmpty) {
            data['id'] = docSnapshot.id;
          }

          return _convertDocToAnalysisResult(data, analysisId);
        } catch (parseError) {
          logError('Belge dönüştürülürken hata oluştu', parseError.toString());

          // Dokümandaki tüm alanları kontrol et
          final data = docSnapshot.data()!;
          final fields = data.keys
              .map((key) =>
                  "$key: ${data[key] is String ? 'String' : (data[key] is List ? 'List' : (data[key] is Map ? 'Map' : 'Other'))}")
              .join(', ');
          logDebug('Belge alanları', fields);

          // En azından temel bilgileri içeren basitleştirilmiş bir sonuç döndür
          return _createSimplifiedErrorResult(
              analysisId, data, parseError.toString());
        }
      },
    );
  }

  /// Hata durumunda basitleştirilmiş bir analiz sonucu oluşturur
  PlantAnalysisResult _createSimplifiedErrorResult(
      String analysisId, Map<String, dynamic> data, String errorMessage) {
    return PlantAnalysisResult(
      id: analysisId,
      plantName: data['plantName'] ?? 'Dönüşüm Hatası',
      probability: 0.0,
      isHealthy: true,
      diseases: [],
      description: 'Analiz sonucu dönüştürülürken hata oluştu: $errorMessage',
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
    // Hastalıkları dönüştür
    List<Disease> diseases = _extractDiseases(data);

    // Önerileri dönüştür
    List<String> suggestions = _extractSuggestions(data);

    // Benzer görüntüleri dönüştür
    List<String> similarImages = _extractSimilarImages(data);

    // Taksonomi bilgisini dönüştür
    PlantTaxonomy? taxonomy = _extractTaxonomy(data);

    // PlantAnalysisResult nesnesini oluştur
    return PlantAnalysisResult(
      id: data['id'] ?? docId,
      plantName: data['plantName'] ?? 'Bilinmeyen Bitki',
      probability:
          (data['probability'] is num) ? data['probability'].toDouble() : 0.0,
      isHealthy: data['isHealthy'] ?? true,
      diseases: diseases,
      description: data['description'] ?? '',
      suggestions: suggestions,
      imageUrl: data['imageUrl'] ?? '',
      similarImages: similarImages,
      taxonomy: taxonomy,
      watering: data['watering'],
      sunlight: data['sunlight'],
      soil: data['soil'],
      climate: data['climate'],
      geminiAnalysis: data['geminiAnalysis'],
      location: data['location'],
      fieldName: data['fieldName'],
      growthStage: data['growthStage'],
      growthScore: _extractGrowthScore(data),
      timestamp: data['timestamp'] is int ? data['timestamp'] : null,
    );
  }

  /// Büyüme skorunu veri haritasından çıkarır
  int? _extractGrowthScore(Map<String, dynamic> data) {
    if (data['growthScore'] is int) {
      return data['growthScore'];
    } else if (data['growthScore'] is String) {
      return int.tryParse(data['growthScore']);
    }
    return null;
  }

  /// Hastalıkları veri haritasından çıkarır
  List<Disease> _extractDiseases(Map<String, dynamic> data) {
    List<Disease> diseases = [];
    if (data.containsKey('diseases') && data['diseases'] is List) {
      final diseasesList = data['diseases'] as List;
      for (final diseaseItem in diseasesList) {
        if (diseaseItem is Map<String, dynamic>) {
          diseases.add(Disease(
            name: diseaseItem['name'] ?? '',
            probability: (diseaseItem['probability'] is num)
                ? diseaseItem['probability'].toDouble()
                : 0.0,
            description: diseaseItem['description'],
          ));
        }
      }
    }
    return diseases;
  }

  /// Önerileri veri haritasından çıkarır
  List<String> _extractSuggestions(Map<String, dynamic> data) {
    List<String> suggestions = [];
    if (data.containsKey('suggestions')) {
      if (data['suggestions'] is List) {
        suggestions = (data['suggestions'] as List)
            .map((item) => item.toString())
            .toList();
      } else if (data['suggestions'] is String) {
        // String ise tek öğeli listeye çevir
        suggestions = [data['suggestions'].toString()];
      }
    }
    return suggestions;
  }

  /// Benzer görüntüleri veri haritasından çıkarır
  List<String> _extractSimilarImages(Map<String, dynamic> data) {
    List<String> similarImages = [];
    if (data.containsKey('similarImages') && data['similarImages'] is List) {
      similarImages = (data['similarImages'] as List)
          .map((item) => item.toString())
          .toList();
    }
    return similarImages;
  }

  /// Taksonomi bilgisini veri haritasından çıkarır
  PlantTaxonomy? _extractTaxonomy(Map<String, dynamic> data) {
    PlantTaxonomy? taxonomy;
    if (data.containsKey('taxonomy') && data['taxonomy'] is Map) {
      final taxMap = data['taxonomy'] as Map<String, dynamic>;
      taxonomy = PlantTaxonomy(
        kingdom: taxMap['kingdom'],
        phylum: taxMap['phylum'],
        class_: taxMap['class'],
        order: taxMap['order'],
        family: taxMap['family'],
        genus: taxMap['genus'],
        species: taxMap['species'],
      );
    }
    return taxonomy;
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

  /// Gemini cevabından PlantAnalysisResult oluştur
  PlantAnalysisResult _parseGeminiResponse(
    String geminiResponse,
    String imageUrl,
    String location,
    String? fieldName,
  ) {
    try {
      // Debug için yanıtın ilk kısmını logla
      final previewLength =
          geminiResponse.length > 100 ? 100 : geminiResponse.length;
      final preview = geminiResponse.substring(0, previewLength);
      logInfo('Gemini yanıtı parse ediliyor', 'Önizleme: $preview...');

      // Gemini yanıtı boş kontrolü
      if (geminiResponse.trim().isEmpty) {
        logError('Gemini yanıtı boş geldi');
        throw Exception('Gemini yanıtı boş');
      }

      // Gemini yanıtını parse işlemini gerçekleştir
      final parsedData = _parseGeminiText(geminiResponse);

      // Parsed data kontrolü
      if (parsedData.isEmpty) {
        logError('Gemini yanıtı parse edilemedi');
        throw Exception('Gemini yanıtından veri çıkarılamadı');
      }

      // Parse edilen verilerin bir kısmını logla
      logInfo('Parse edilen veriler',
          'Bitki adı: ${parsedData['plantName']}, Sağlıklı: ${parsedData['isHealthy']}');

      // Tüm önerileri birleştir
      List<String> allSuggestions = _combineAllSuggestions(
        parsedData,
        location,
      );

      // Açıklamayı hazırla
      String fullDescription = _prepareFullDescription(
        parsedData['description'] as String? ?? '',
        parsedData['soil'] as String?,
        parsedData['climate'] as String?,
      );

      // Sonuç nesnesini oluştur
      return PlantAnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        plantName: parsedData['plantName'] as String? ?? 'Bilinmeyen Bitki',
        probability: 0.9, // Gemini'den kesin bir olasılık alamıyoruz
        isHealthy: parsedData['isHealthy'] as bool? ?? true,
        diseases: parsedData['diseases'] as List<Disease>? ?? [],
        description: fullDescription,
        suggestions: allSuggestions,
        imageUrl: imageUrl,
        similarImages: [], // Gemini benzer görüntü sağlamıyor
        watering: parsedData['watering'] as String?,
        sunlight: parsedData['sunlight'] as String?,
        geminiAnalysis: geminiResponse, // Tam Gemini yanıtı
        location: location, // Konum bilgisini de ekle
        fieldName: fieldName,
        growthStage: parsedData['growthStage'] as String?,
        growthScore: parsedData['growthScore'] as int?,
      );
    } catch (e) {
      logError('Gemini yanıtını işleme hatası', e.toString());

      // Hata bilgisini daha detaylı al
      String errorDetails = '';
      try {
        // Yanıtın ilk 200 karakteri
        if (geminiResponse.isNotEmpty) {
          final previewLength =
              geminiResponse.length > 200 ? 200 : geminiResponse.length;
          errorDetails =
              'İlk ${previewLength} karakter: ${geminiResponse.substring(0, previewLength)}';
        } else {
          errorDetails = 'Yanıt boş';
        }
      } catch (logError) {
        errorDetails = 'Yanıt detayları alınamadı: $logError';
      }

      logError('Gemini yanıtı detayları', errorDetails);

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

  /// Gemini yanıt metnini parçalara ayırır
  Map<String, dynamic> _parseGeminiText(String geminiResponse) {
    // Sonuç değişkenleri
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
    String currentSection = '';

    for (final line in lines) {
      final trimmedLine = line.trim();

      // Boş satırları atla
      if (trimmedLine.isEmpty) continue;

      // Başlıkları tanımla ve işle
      if (trimmedLine.startsWith('BITKI_ADI:')) {
        currentSection = 'plantName';
        plantName = trimmedLine.substring('BITKI_ADI:'.length).trim();
      } else if (trimmedLine.startsWith('SAGLIK_DURUMU:')) {
        currentSection = 'healthStatus';
        final status =
            trimmedLine.substring('SAGLIK_DURUMU:'.length).trim().toLowerCase();
        isHealthy =
            status.contains('sağlıklı') && !status.contains('sağlıksız');
      } else if (trimmedLine.startsWith('TANIM:')) {
        currentSection = 'description';
        description = trimmedLine.substring('TANIM:'.length).trim();
      } else if (trimmedLine.startsWith('HASTALIKLAR:')) {
        currentSection = 'diseases';
      } else if (trimmedLine.startsWith('MUDAHALE_YONTEMLERI:')) {
        currentSection = 'interventions';
      } else if (trimmedLine.startsWith('TARIMSAL_ONERILER:')) {
        currentSection = 'agriculturalTips';
      } else if (trimmedLine.startsWith('BOLGESEL_BILGILER:')) {
        currentSection = 'regionalInfo';
      } else if (trimmedLine.startsWith('ONERILER:')) {
        currentSection = 'suggestions';
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
        final scoreText = trimmedLine.substring('GELISIM_SKORU:'.length).trim();
        // Sayısal değeri ayıkla (70/100 veya sadece 70 formatından)
        final scoreRegex = RegExp(r'(\d+)');
        final match = scoreRegex.firstMatch(scoreText);
        if (match != null) {
          growthScore = int.tryParse(match.group(1) ?? '0') ?? 0;
        }
      } else if (trimmedLine.startsWith('GELISIM_YORUMU:')) {
        currentSection = 'growthComment';
        growthComment = trimmedLine.substring('GELISIM_YORUMU:'.length).trim();
      }
      // İçeriği bölümlere göre işle
      else {
        _processContentLine(
          currentSection,
          trimmedLine,
          diseases,
          description,
          interventionMethods,
          agriculturalTips,
          regionalInfo,
          suggestions,
          growthComment,
        );
      }
    }

    // Gelişim aşamasına göre tahmini gelişim skoru ata
    if (growthScore == null && growthStage != null) {
      growthScore = _estimateGrowthScore(growthStage);
    }

    // Tüm parse edilmiş verileri bir haritada döndür
    return {
      'plantName': plantName,
      'isHealthy': isHealthy,
      'description': description,
      'diseases': diseases,
      'suggestions': suggestions,
      'interventionMethods': interventionMethods,
      'agriculturalTips': agriculturalTips,
      'regionalInfo': regionalInfo,
      'watering': watering,
      'sunlight': sunlight,
      'soil': soil,
      'climate': climate,
      'growthStage': growthStage,
      'growthScore': growthScore,
      'growthComment': growthComment,
    };
  }

  /// Gelişim aşamasına göre tahmini bir gelişim skoru hesaplar
  int _estimateGrowthScore(String growthStage) {
    final stageLower = growthStage.toLowerCase();
    if (stageLower.contains('olgun') ||
        stageLower.contains('hasat') ||
        stageLower.contains('olgunlaşma')) {
      return 85;
    } else if (stageLower.contains('çiçek') ||
        stageLower.contains('cicek') ||
        stageLower.contains('meyve')) {
      return 70;
    } else if (stageLower.contains('büyüme') ||
        stageLower.contains('gelişme') ||
        stageLower.contains('genc')) {
      return 50;
    } else if (stageLower.contains('fide') ||
        stageLower.contains('çimlenme') ||
        stageLower.contains('yeni')) {
      return 30;
    } else {
      return 60; // Varsayılan orta düzey
    }
  }

  /// İçerik satırını mevcut bölüme göre işler
  void _processContentLine(
    String currentSection,
    String trimmedLine,
    List<Disease> diseases,
    String description,
    List<String> interventionMethods,
    List<String> agriculturalTips,
    List<String> regionalInfo,
    List<String> suggestions,
    String? growthComment,
  ) {
    if (currentSection == 'diseases' && trimmedLine.startsWith('-')) {
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
    } else if (currentSection == 'suggestions' && trimmedLine.startsWith('-')) {
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

  /// Tüm öneri türlerini birleştirir
  List<String> _combineAllSuggestions(
      Map<String, dynamic> parsedData, String location) {
    List<String> allSuggestions = [];
    final interventionMethods =
        parsedData['interventionMethods'] as List<String>? ?? [];
    final agriculturalTips =
        parsedData['agriculturalTips'] as List<String>? ?? [];
    final regionalInfo = parsedData['regionalInfo'] as List<String>? ?? [];
    final suggestions = parsedData['suggestions'] as List<String>? ?? [];

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

    return allSuggestions;
  }

  /// Tam açıklama metnini hazırlar
  String _prepareFullDescription(
      String description, String? soil, String? climate) {
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

    return fullDescription;
  }
}
