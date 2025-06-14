import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore veritabanı işlemleri için abstract interface
///
/// Bu interface, Firestore ile yapılacak tüm veritabanı işlemlerini
/// tanımlar ve test edilebilirlik için dependency injection'a olanak sağlar.
///
/// Özellikler:
/// - Generic CRUD operasyonları
/// - Query builder pattern desteği
/// - Batch işlemler
/// - Real-time listener'lar
/// - Error handling
/// - Type safety
abstract class FirestoreServiceInterface {
  /// Firestore instance'ını döner
  FirebaseFirestore get firestore;

  /// Tek bir dokuman okur
  ///
  /// [collection] - Koleksiyon adı
  /// [documentId] - Dokuman ID'si
  /// [fromJson] - JSON'dan model'e çevirme fonksiyonu
  ///
  /// Returns: Model instance veya null (dokuman yoksa)
  Future<T?> getDocument<T>({
    required String collection,
    required String documentId,
    required T Function(Map<String, dynamic>) fromJson,
  });

  /// Birden fazla dokuman okur (basit query)
  ///
  /// [collection] - Koleksiyon adı
  /// [fromJson] - JSON'dan model'e çevirme fonksiyonu
  /// [limit] - Maksimum döndürülecek dokuman sayısı
  /// [orderBy] - Sıralama field'ı
  /// [descending] - Azalan sıralama (varsayılan: false)
  ///
  /// Returns: Model listesi
  Future<List<T>> getDocuments<T>({
    required String collection,
    required T Function(Map<String, dynamic>) fromJson,
    int? limit,
    String? orderBy,
    bool descending = false,
  });

  /// Gelişmiş query ile dokuman okur
  ///
  /// [collection] - Koleksiyon adı
  /// [fromJson] - JSON'dan model'e çevirme fonksiyonu
  /// [queryBuilder] - Query oluşturma fonksiyonu
  ///
  /// Returns: Model listesi
  Future<List<T>> getDocumentsWithQuery<T>({
    required String collection,
    required T Function(Map<String, dynamic>) fromJson,
    required Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>>)
        queryBuilder,
  });

  /// Tek bir dokuman ekler/günceller
  ///
  /// [collection] - Koleksiyon adı
  /// [documentId] - Dokuman ID'si (null ise otomatik generate)
  /// [data] - Eklenecek/güncellenecek veri
  /// [merge] - Mevcut veriyle birleştir (varsayılan: true)
  ///
  /// Returns: Dokuman ID'si
  Future<String> setDocument({
    required String collection,
    String? documentId,
    required Map<String, dynamic> data,
    bool merge = true,
  });

  /// Tek bir dokuman günceller (sadece belirli field'ları)
  ///
  /// [collection] - Koleksiyon adı
  /// [documentId] - Dokuman ID'si
  /// [data] - Güncellenecek field'lar
  ///
  /// Returns: void
  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  });

  /// Tek bir dokuman siler
  ///
  /// [collection] - Koleksiyon adı
  /// [documentId] - Dokuman ID'si
  ///
  /// Returns: void
  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  });

  /// Belirli koşullara uyan dokümanları siler
  ///
  /// [collection] - Koleksiyon adı
  /// [queryBuilder] - Silinecek dokümanları bulmak için query
  ///
  /// Returns: Silinen dokuman sayısı
  Future<int> deleteDocumentsWithQuery({
    required String collection,
    required Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>>)
        queryBuilder,
  });

  /// Batch işlem başlatır
  ///
  /// Returns: WriteBatch instance
  WriteBatch batch();

  /// Batch işlemi commit eder
  ///
  /// [batch] - WriteBatch instance
  ///
  /// Returns: void
  Future<void> commitBatch(WriteBatch batch);

  /// Real-time dokuman dinleyici oluşturur
  ///
  /// [collection] - Koleksiyon adı
  /// [documentId] - Dokuman ID'si
  /// [fromJson] - JSON'dan model'e çevirme fonksiyonu
  /// [onData] - Veri geldiğinde çalışacak callback
  /// [onError] - Hata oluştuğunda çalışacak callback
  ///
  /// Returns: StreamSubscription (iptal etmek için)
  Stream<T?> documentStream<T>({
    required String collection,
    required String documentId,
    required T Function(Map<String, dynamic>) fromJson,
  });

  /// Real-time koleksiyon dinleyici oluşturur
  ///
  /// [collection] - Koleksiyon adı
  /// [fromJson] - JSON'dan model'e çevirme fonksiyonu
  /// [queryBuilder] - Query oluşturma fonksiyonu (opsiyonel)
  ///
  /// Returns: Stream of model listesi
  Stream<List<T>> collectionStream<T>({
    required String collection,
    required T Function(Map<String, dynamic>) fromJson,
    Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>>)?
        queryBuilder,
  });

  /// Transaction başlatır
  ///
  /// [updateFunction] - Transaction içinde çalışacak fonksiyon
  ///
  /// Returns: Transaction sonucu
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  );

  /// Koleksiyonun var olup olmadığını kontrol eder
  ///
  /// [collection] - Koleksiyon adı
  ///
  /// Returns: Koleksiyon var mı?
  Future<bool> collectionExists(String collection);

  /// Dokuman var olup olmadığını kontrol eder
  ///
  /// [collection] - Koleksiyon adı
  /// [documentId] - Dokuman ID'si
  ///
  /// Returns: Dokuman var mı?
  Future<bool> documentExists({
    required String collection,
    required String documentId,
  });

  /// Koleksiyondaki toplam dokuman sayısını döner
  ///
  /// [collection] - Koleksiyon adı
  /// [queryBuilder] - Count query (opsiyonel)
  ///
  /// Returns: Dokuman sayısı
  Future<int> getDocumentCount({
    required String collection,
    Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>>)?
        queryBuilder,
  });

  /// Sub-collection'a erişim sağlar
  ///
  /// [collection] - Ana koleksiyon adı
  /// [documentId] - Ana dokuman ID'si
  /// [subCollection] - Alt koleksiyon adı
  ///
  /// Returns: CollectionReference
  CollectionReference<Map<String, dynamic>> getSubCollection({
    required String collection,
    required String documentId,
    required String subCollection,
  });

  /// Pagination için cursor-based query
  ///
  /// [collection] - Koleksiyon adı
  /// [fromJson] - JSON'dan model'e çevirme fonksiyonu
  /// [limit] - Sayfa başına dokuman sayısı
  /// [orderBy] - Sıralama field'ı
  /// [descending] - Azalan sıralama
  /// [startAfterDocument] - Başlangıç cursor dokuman
  ///
  /// Returns: Sayfalama sonucu
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
  });

  /// Servis dispose işlemi
  void dispose();
}

/// Firestore pagination sonuç modeli
class FirestorePaginationResult<T> {
  /// Döndürülen dokümanlar
  final List<T> documents;

  /// Son dokuman (next page için cursor)
  final DocumentSnapshot? lastDocument;

  /// Daha fazla sayfa var mı?
  final bool hasNextPage;

  const FirestorePaginationResult({
    required this.documents,
    this.lastDocument,
    required this.hasNextPage,
  });

  @override
  String toString() {
    return 'FirestorePaginationResult{documents: ${documents.length}, hasNextPage: $hasNextPage}';
  }
}

/// Firestore query tipleri
enum FirestoreQueryType {
  /// Eşittir
  isEqualTo,

  /// Eşit değildir
  isNotEqualTo,

  /// Büyüktür
  isGreaterThan,

  /// Büyük eşittir
  isGreaterThanOrEqualTo,

  /// Küçüktür
  isLessThan,

  /// Küçük eşittir
  isLessThanOrEqualTo,

  /// Dizi içinde
  arrayContains,

  /// Dizi içinde herhangi biri
  arrayContainsAny,

  /// İçinde (in)
  whereIn,

  /// İçinde değil (not in)
  whereNotIn,

  /// Null mı?
  isNull,
}

/// Firestore query builder helper
class FirestoreQueryBuilder {
  final List<FirestoreQueryCondition> _conditions = [];
  final List<FirestoreOrderBy> _orderBy = [];
  int? _limit;

  /// Where koşulu ekler
  FirestoreQueryBuilder where(
    String field,
    FirestoreQueryType type,
    dynamic value,
  ) {
    _conditions.add(FirestoreQueryCondition(
      field: field,
      type: type,
      value: value,
    ));
    return this;
  }

  /// Order by ekler
  FirestoreQueryBuilder orderBy(String field, {bool descending = false}) {
    _orderBy.add(FirestoreOrderBy(
      field: field,
      descending: descending,
    ));
    return this;
  }

  /// Limit ekler
  FirestoreQueryBuilder limit(int limit) {
    _limit = limit;
    return this;
  }

  /// Query'yi build eder
  Query<Map<String, dynamic>> build(
      CollectionReference<Map<String, dynamic>> collection) {
    Query<Map<String, dynamic>> query = collection;

    // Where koşullarını ekle
    for (final condition in _conditions) {
      query = _applyCondition(query, condition);
    }

    // Order by'ları ekle
    for (final order in _orderBy) {
      query = query.orderBy(order.field, descending: order.descending);
    }

    // Limit ekle
    if (_limit != null) {
      query = query.limit(_limit!);
    }

    return query;
  }

  /// Koşulu query'ye uygular
  Query<Map<String, dynamic>> _applyCondition(
    Query<Map<String, dynamic>> query,
    FirestoreQueryCondition condition,
  ) {
    switch (condition.type) {
      case FirestoreQueryType.isEqualTo:
        return query.where(condition.field, isEqualTo: condition.value);
      case FirestoreQueryType.isNotEqualTo:
        return query.where(condition.field, isNotEqualTo: condition.value);
      case FirestoreQueryType.isGreaterThan:
        return query.where(condition.field, isGreaterThan: condition.value);
      case FirestoreQueryType.isGreaterThanOrEqualTo:
        return query.where(condition.field,
            isGreaterThanOrEqualTo: condition.value);
      case FirestoreQueryType.isLessThan:
        return query.where(condition.field, isLessThan: condition.value);
      case FirestoreQueryType.isLessThanOrEqualTo:
        return query.where(condition.field,
            isLessThanOrEqualTo: condition.value);
      case FirestoreQueryType.arrayContains:
        return query.where(condition.field, arrayContains: condition.value);
      case FirestoreQueryType.arrayContainsAny:
        return query.where(condition.field, arrayContainsAny: condition.value);
      case FirestoreQueryType.whereIn:
        return query.where(condition.field, whereIn: condition.value);
      case FirestoreQueryType.whereNotIn:
        return query.where(condition.field, whereNotIn: condition.value);
      case FirestoreQueryType.isNull:
        return query.where(condition.field, isNull: condition.value);
    }
  }
}

/// Firestore query koşulu
class FirestoreQueryCondition {
  final String field;
  final FirestoreQueryType type;
  final dynamic value;

  const FirestoreQueryCondition({
    required this.field,
    required this.type,
    required this.value,
  });
}

/// Firestore order by
class FirestoreOrderBy {
  final String field;
  final bool descending;

  const FirestoreOrderBy({
    required this.field,
    required this.descending,
  });
}
