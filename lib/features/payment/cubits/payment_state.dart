part of 'payment_cubit.dart';

class PaymentState extends Equatable {
  final bool isLoading;
  final bool isProcessingPurchase;
  final bool hasError;
  final bool isPremium;
  final Offerings? offerings;
  final CustomerInfo? customerInfo;
  final int remainingFreeAnalyses;

  const PaymentState({
    this.isLoading = false,
    this.isProcessingPurchase = false,
    this.hasError = false,
    this.isPremium = false,
    this.offerings,
    this.customerInfo,
    this.remainingFreeAnalyses = 3, // Varsayılan olarak 3 analiz hakkı
  });

  PaymentState copyWith({
    bool? isLoading,
    bool? isProcessingPurchase,
    bool? hasError,
    bool? isPremium,
    Offerings? offerings,
    CustomerInfo? customerInfo,
    int? remainingFreeAnalyses,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      isProcessingPurchase: isProcessingPurchase ?? this.isProcessingPurchase,
      hasError: hasError ?? this.hasError,
      isPremium: isPremium ?? this.isPremium,
      offerings: offerings ?? this.offerings,
      customerInfo: customerInfo ?? this.customerInfo,
      remainingFreeAnalyses:
          remainingFreeAnalyses ?? this.remainingFreeAnalyses,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isProcessingPurchase,
        hasError,
        isPremium,
        offerings,
        customerInfo,
        remainingFreeAnalyses,
      ];
}
