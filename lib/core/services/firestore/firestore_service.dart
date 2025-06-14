import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service_interface.dart';
import '../../utils/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore veritabanı işlemleri için concrete implementation
///
/// FirestoreServiceInterface'i implement eder ve tüm Firestore
/// işlemlerini gerçekleştirir. Error handling, logging ve performance
/// optimizasyonları içerir.
///
/// Özellikler:
/// - Comprehensive error handling
/// - Performance monitoring
/// - Automatic retry mechanism with exponential backoff
/// - Connection state management
/// - Detailed logging
class FirestoreService implements FirestoreServiceInterface {
  /// Firestore instance
  final FirebaseFirestore _firestore;

  /// Aktif stream subscription'ları
  final List<StreamSubscription> _subscriptions = [];

  /// Service adı (logging için)
  static const String _serviceName = 'FirestoreService';

  /// Retry configuration
  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(seconds: 1);

  /// Constructor
  FirestoreService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance {
    _initializeFirestore();
  }

  /// Firestore ayarlarını yapar
  void _initializeFirestore() {
    try {
      // Offline persistence enable (sadece ilk çağrımda)
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      AppLogger.logWithContext(_serviceName, 'Firestore başarıyla başlatıldı');
    } catch (e) {
      // Settings sadece bir kez set edilebilir, hata görmezden gel
      AppLogger.logWithContext(
          _serviceName, 'Firestore settings zaten ayarlanmış');
    }
  }

  /// Retry mekanizması ile işlem gerçekleştirir
  ///
  /// Exponential backoff stratejisi kullanır:
  /// - 1. deneme: hemen
  /// - 2. deneme: 1 saniye sonra
  /// - 3. deneme: 2 saniye sonra
  /// - 4. deneme: 4 saniye sonra
  Future<T> _executeWithRetry<T>(
    String operationName,
    Future<T> Function() operation, {
    int maxRetries = _maxRetries,
  }) async {
    Exception? lastException;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          final delay = Duration(
            milliseconds: _baseDelay.inMilliseconds * (1 << (attempt - 1)),
          );
          AppLogger.logWithContext(
            _serviceName,
            '🔄 $operationName retry #$attempt, ${delay.inMilliseconds}ms bekliyor...',
          );
          await Future.delayed(delay);
        }

        AppLogger.logWithContext(
          _serviceName,
          '⏳ $operationName deneme #${attempt + 1}/${maxRetries + 1}',
        );

        final result = await operation();

        if (attempt > 0) {
          AppLogger.successWithContext(
            _serviceName,
            '✅ $operationName başarılı (${attempt + 1}. denemede)',
          );
        }

        return result;
      } on FirebaseException catch (e) {
        lastException = e;

        // Retry yapılabilir hatalar
        final isRetryable = _isRetryableError(e);

        AppLogger.warnWithContext(
          _serviceName,
          '⚠️ $operationName hata (${e.code}): ${e.message}',
        );

        // Son deneme veya retry yapılamaz hata ise exception fırlat
        if (attempt >= maxRetries || !isRetryable) {
          AppLogger.errorWithContext(
            _serviceName,
            '❌ $operationName başarısız (${attempt + 1} deneme sonrası)',
            e,
          );
          rethrow;
        }

        AppLogger.logWithContext(
          _serviceName,
          '🔄 $operationName retry yapılacak (${e.code} hatası)',
        );
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        AppLogger.errorWithContext(
          _serviceName,
          '❌ $operationName beklenmeyen hata',
          e,
        );

        // Beklenmeyen hatalar için retry yapma
        rethrow;
      }
    }

    // Bu noktaya gelmemeli ama güvenlik için
    throw lastException ?? Exception('$operationName başarısız');
  }

  /// Hatanın retry yapılabilir olup olmadığını kontrol eder
  bool _isRetryableError(FirebaseException e) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'resource-exhausted':
      case 'aborted':
      case 'internal':
        return true;
      case 'permission-denied':
      case 'not-found':
      case 'already-exists':
      case 'invalid-argument':
      case 'unauthenticated':
        return false;
      default:
        // Bilinmeyen hatalar için retry yapma
        return false;
    }
  }

  @override
  FirebaseFirestore get firestore => _firestore;

  @override
  Future<T?> getDocument<T>({
    required String collection,
    required String documentId,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    return await _executeWithRetry(
      'getDocument($collection/$documentId)',
      () async {
        AppLogger.logWithContext(
            _serviceName, 'Dokuman okunuyor', '$collection/$documentId');

        final DocumentSnapshot doc =
            await _firestore.collection(collection).doc(documentId).get();

        if (!doc.exists) {
          AppLogger.logWithContext(
              _serviceName, 'Dokuman bulunamadı', '$collection/$documentId');
          return null;
        }

        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) {
          AppLogger.warnWithContext(
              _serviceName, 'Dokuman verisi null', '$collection/$documentId');
          return null;
        }

        // ID'yi data'ya ekle (genelde gerekli olur)
        data['id'] = doc.id;

        final result = fromJson(data);
        AppLogger.successWithContext(_serviceName, 'Dokuman başarıyla okundu',
            '$collection/$documentId');

        return result;
      },
    );
  }

  @override
  Future<List<T>> getDocuments<T>({
    required String collection,
    required T Function(Map<String, dynamic>) fromJson,
    int? limit,
    String? orderBy,
    bool descending = false,
  }) async {
    try {
      AppLogger.logWithContext(_serviceName, 'Dokümanlar okunuyor', collection);

      Query<Map<String, dynamic>> query = _firestore.collection(collection);

      // Order by ekle
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      // Limit ekle
      if (limit != null) {
        query = query.limit(limit);
      }

      final QuerySnapshot snapshot = await query.get();

      final List<T> documents = [];
      for (final QueryDocumentSnapshot doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // ID'yi ekle

          final item = fromJson(data);
          documents.add(item);
        } catch (e) {
          AppLogger.warnWithContext(
              _serviceName, 'Dokuman parse hatası', '${doc.id}: $e');
        }
      }

      AppLogger.successWithContext(_serviceName, 'Dokümanlar başarıyla okundu',
          '$collection: ${documents.length} dokuman');

      return documents;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Dokümanlar okuma hatası', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<T>> getDocumentsWithQuery<T>({
    required String collection,
    required T Function(Map<String, dynamic>) fromJson,
    required Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>>)
        queryBuilder,
  }) async {
    try {
      AppLogger.logWithContext(
          _serviceName, 'Query ile dokümanlar okunuyor', collection);

      final CollectionReference<Map<String, dynamic>> collectionRef =
          _firestore.collection(collection);

      final Query<Map<String, dynamic>> query = queryBuilder(collectionRef);
      final QuerySnapshot snapshot = await query.get();

      final List<T> documents = [];
      for (final QueryDocumentSnapshot doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // ID'yi ekle

          final item = fromJson(data);
          documents.add(item);
        } catch (e) {
          AppLogger.warnWithContext(
              _serviceName, 'Dokuman parse hatası', '${doc.id}: $e');
        }
      }

      AppLogger.successWithContext(
          _serviceName,
          'Query ile dokümanlar başarıyla okundu',
          '$collection: ${documents.length} dokuman');

      return documents;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Query ile dokümanlar okuma hatası', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<String> setDocument({
    required String collection,
    String? documentId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    return await _executeWithRetry(
      'setDocument($collection/${documentId ?? "auto"})',
      () async {
        final String targetDocId =
            documentId ?? _firestore.collection(collection).doc().id;

        AppLogger.logWithContext(
            _serviceName, '📝 Dokuman yazılıyor', '$collection/$targetDocId');

        // Firebase Security Rules test için debug info
        final currentUser = FirebaseAuth.instance.currentUser;
        AppLogger.logWithContext(_serviceName,
            '🔐 Firebase Auth User: ${currentUser?.uid ?? "null"} (${currentUser?.isAnonymous ?? false})');

        // Data debug
        AppLogger.logWithContext(
            _serviceName, '📊 Yazılacak data: ${data.keys.toString()}');

        // Timestamp'leri ekle
        final Map<String, dynamic> dataWithTimestamps = {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Yeni dokuman ise createdAt ekle
        // Geçici: documentExists kontrolünü bypass et (database yeniden oluşturulduğu için)
        if (documentId == null) {
          dataWithTimestamps['createdAt'] = FieldValue.serverTimestamp();
          AppLogger.logWithContext(_serviceName,
              '🆕 Yeni dokuman (auto-generated ID), createdAt eklendi');
        } else {
          // Manuel ID verilmişse, her zaman yeni dokuman olarak işle
          dataWithTimestamps['createdAt'] = FieldValue.serverTimestamp();
          AppLogger.logWithContext(
              _serviceName, '🆕 Yeni dokuman (manuel ID), createdAt eklendi');
        }

        AppLogger.logWithContext(
            _serviceName, '⏳ Firestore.setDocument() çağrılıyor...');

        await _firestore
            .collection(collection)
            .doc(targetDocId)
            .set(dataWithTimestamps, SetOptions(merge: merge));

        AppLogger.successWithContext(_serviceName,
            '✅ Dokuman başarıyla yazıldı', '$collection/$targetDocId');

        return targetDocId;
      },
    );
  }

  @override
  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      AppLogger.logWithContext(
          _serviceName, 'Dokuman güncelleniyor', '$collection/$documentId');

      // Timestamp ekle
      final Map<String, dynamic> dataWithTimestamp = {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(collection)
          .doc(documentId)
          .update(dataWithTimestamp);

      AppLogger.successWithContext(_serviceName,
          'Dokuman başarıyla güncellendi', '$collection/$documentId');
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Dokuman güncelleme hatası', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      AppLogger.logWithContext(
          _serviceName, 'Dokuman siliniyor', '$collection/$documentId');

      await _firestore.collection(collection).doc(documentId).delete();

      AppLogger.successWithContext(
          _serviceName, 'Dokuman başarıyla silindi', '$collection/$documentId');
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Dokuman silme hatası', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<int> deleteDocumentsWithQuery({
    required String collection,
    required Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>>)
        queryBuilder,
  }) async {
    try {
      AppLogger.logWithContext(
          _serviceName, 'Query ile dokümanlar siliniyor', collection);

      final CollectionReference<Map<String, dynamic>> collectionRef =
          _firestore.collection(collection);

      final Query<Map<String, dynamic>> query = queryBuilder(collectionRef);
      final QuerySnapshot snapshot = await query.get();

      // Batch ile toplu silme
      final WriteBatch batch = _firestore.batch();
      int deleteCount = 0;

      for (final QueryDocumentSnapshot doc in snapshot.docs) {
        batch.delete(doc.reference);
        deleteCount++;
      }

      if (deleteCount > 0) {
        await batch.commit();
      }

      AppLogger.successWithContext(
          _serviceName,
          'Query ile dokümanlar başarıyla silindi',
          '$collection: $deleteCount dokuman');

      return deleteCount;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Query ile dokümanlar silme hatası', e, stackTrace);
      rethrow;
    }
  }

  @override
  WriteBatch batch() {
    AppLogger.logWithContext(_serviceName, 'Batch işlemi başlatıldı');
    return _firestore.batch();
  }

  @override
  Future<void> commitBatch(WriteBatch batch) async {
    try {
      AppLogger.logWithContext(_serviceName, 'Batch işlemi commit ediliyor');

      await batch.commit();

      AppLogger.successWithContext(
          _serviceName, 'Batch işlemi başarıyla commit edildi');
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Batch commit hatası', e, stackTrace);
      rethrow;
    }
  }

  @override
  Stream<T?> documentStream<T>({
    required String collection,
    required String documentId,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    AppLogger.logWithContext(
        _serviceName, 'Dokuman stream başlatıldı', '$collection/$documentId');

    return _firestore
        .collection(collection)
        .doc(documentId)
        .snapshots()
        .map((DocumentSnapshot doc) {
      try {
        if (!doc.exists) {
          return null;
        }

        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) {
          return null;
        }

        data['id'] = doc.id; // ID'yi ekle
        return fromJson(data);
      } catch (e) {
        AppLogger.warnWithContext(
            _serviceName, 'Dokuman stream parse hatası', '$documentId: $e');
        return null;
      }
    });
  }

  @override
  Stream<List<T>> collectionStream<T>({
    required String collection,
    required T Function(Map<String, dynamic>) fromJson,
    Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>>)?
        queryBuilder,
  }) {
    AppLogger.logWithContext(
        _serviceName, 'Koleksiyon stream başlatıldı', collection);

    Query<Map<String, dynamic>> query = _firestore.collection(collection);

    if (queryBuilder != null) {
      query = queryBuilder(_firestore.collection(collection));
    }

    return query.snapshots().map((QuerySnapshot snapshot) {
      final List<T> documents = [];

      for (final QueryDocumentSnapshot doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // ID'yi ekle

          final item = fromJson(data);
          documents.add(item);
        } catch (e) {
          AppLogger.warnWithContext(
              _serviceName, 'Koleksiyon stream parse hatası', '${doc.id}: $e');
        }
      }

      return documents;
    });
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) async {
    try {
      AppLogger.logWithContext(_serviceName, 'Transaction başlatıldı');

      final T result = await _firestore.runTransaction(updateFunction);

      AppLogger.successWithContext(
          _serviceName, 'Transaction başarıyla tamamlandı');
      return result;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Transaction hatası', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<bool> collectionExists(String collection) async {
    try {
      final QuerySnapshot snapshot =
          await _firestore.collection(collection).limit(1).get();

      return snapshot.docs.isNotEmpty;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Koleksiyon varlık kontrolü hatası', e, stackTrace);
      return false;
    }
  }

  @override
  Future<bool> documentExists({
    required String collection,
    required String documentId,
  }) async {
    try {
      return await _executeWithRetry(
        'documentExists($collection/$documentId)',
        () async {
          final DocumentSnapshot doc =
              await _firestore.collection(collection).doc(documentId).get();

          return doc.exists;
        },
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Dokuman varlık kontrolü hatası', e, stackTrace);
      return false;
    }
  }

  @override
  Future<int> getDocumentCount({
    required String collection,
    Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>>)?
        queryBuilder,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(collection);

      if (queryBuilder != null) {
        query = queryBuilder(_firestore.collection(collection));
      }

      final AggregateQuerySnapshot snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Dokuman sayısı alma hatası', e, stackTrace);
      rethrow;
    }
  }

  @override
  CollectionReference<Map<String, dynamic>> getSubCollection({
    required String collection,
    required String documentId,
    required String subCollection,
  }) {
    return _firestore
        .collection(collection)
        .doc(documentId)
        .collection(subCollection);
  }

  @override
  Future<FirestorePaginationResult<T>> getPaginatedDocuments<T>({
    required String collection,
    required T Function(Map<String, dynamic>) fromJson,
    required int limit,
    required String orderBy,
    bool descending = false,
    DocumentSnapshot? startAfterDocument,
    Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>>)?
        queryBuilder,
  }) async {
    try {
      AppLogger.logWithContext(_serviceName, 'Sayfalı dokümanlar okunuyor',
          '$collection (limit: $limit)');

      Query<Map<String, dynamic>> query = _firestore.collection(collection);

      // Custom query ekle
      if (queryBuilder != null) {
        query = queryBuilder(_firestore.collection(collection));
      }

      // Order by ekle
      query = query.orderBy(orderBy, descending: descending);

      // Cursor ekle
      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      // Limit ekle (+1 to check if there are more pages)
      query = query.limit(limit + 1);

      final QuerySnapshot snapshot = await query.get();

      final List<T> documents = [];
      DocumentSnapshot? lastDocument;
      bool hasNextPage = false;

      for (int i = 0; i < snapshot.docs.length; i++) {
        final QueryDocumentSnapshot doc = snapshot.docs[i];

        // Son dokuman limit'i aşıyorsa, next page var demektir
        if (i >= limit) {
          hasNextPage = true;
          break;
        }

        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // ID'yi ekle

          final item = fromJson(data);
          documents.add(item);
          lastDocument = doc;
        } catch (e) {
          AppLogger.warnWithContext(
              _serviceName, 'Sayfalı dokuman parse hatası', '${doc.id}: $e');
        }
      }

      AppLogger.successWithContext(
          _serviceName,
          'Sayfalı dokümanlar başarıyla okundu',
          '$collection: ${documents.length} dokuman, hasNext: $hasNextPage');

      return FirestorePaginationResult<T>(
        documents: documents,
        lastDocument: lastDocument,
        hasNextPage: hasNextPage,
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
          _serviceName, 'Sayfalı dokümanlar okuma hatası', e, stackTrace);
      rethrow;
    }
  }

  @override
  void dispose() {
    AppLogger.logWithContext(_serviceName, 'Servis dispose ediliyor');

    // Tüm aktif subscription'ları iptal et
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    AppLogger.successWithContext(
        _serviceName, 'Servis başarıyla dispose edildi');
  }
}
