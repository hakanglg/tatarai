import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tatarai/core/constants/app_constants.dart';
import 'package:tatarai/core/utils/validation_util.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/core/models/user_model.dart';
import 'package:tatarai/features/plant_analysis/services/gemini_service.dart';
import 'package:tatarai/features/plant_analysis/data/models/plant_analysis_result.dart';

/// Plant Analysis Service Result Types
///
/// Defines the various result types for plant analysis operations
enum AnalysisServiceResultType {
  /// Analysis completed successfully
  success,

  /// User authentication error (not logged in)
  userAuthError,

  /// Premium subscription required
  premiumRequired,

  /// Network connectivity error
  connectivityError,

  /// Insufficient analysis credits
  creditError,

  /// External API error
  apiError,

  /// General/unknown error
  generalError,
}

/// Plant Analysis Service
///
/// Handles plant analysis operations with user validation, credit management,
/// and integration with AI analysis services. Follows Clean Architecture
/// principles with proper separation of concerns.
///
/// Features:
/// - User authentication and authorization
/// - Credit system management
/// - Premium feature access control
/// - Network connectivity validation
/// - Error handling and logging
/// - Integration with Gemini AI service
class PlantAnalysisService {
  // ============================================================================
  // DEPENDENCIES
  // ============================================================================

  /// Gemini AI service for plant analysis
  final GeminiService _geminiService;

  /// Firestore instance for user data management
  final FirebaseFirestore _firestore;

  /// Firebase Storage for image uploads
  final FirebaseStorage _storage;

  /// Service name for logging context
  static const String _serviceName = 'PlantAnalysisService';

  // ============================================================================
  // CONSTRUCTOR
  // ============================================================================

  /// Creates PlantAnalysisService with required dependencies
  ///
  /// @param geminiService - AI analysis service
  /// @param firestore - Firestore database instance
  /// @param storage - Firebase storage instance
  PlantAnalysisService({
    required GeminiService geminiService,
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _geminiService = geminiService,
        _firestore = firestore,
        _storage = storage {
    AppLogger.logWithContext(_serviceName, 'Service initialized');
  }

  // ============================================================================
  // PUBLIC METHODS
  // ============================================================================

  /// Analyzes plant image with comprehensive validation
  ///
  /// Performs complete plant analysis workflow:
  /// 1. User authentication validation
  /// 2. Network connectivity check
  /// 3. User credits verification
  /// 4. Location info preparation
  /// 5. AI analysis execution
  /// 6. Credit deduction
  ///
  /// @param imageBytes - Image data to analyze
  /// @param user - User performing the analysis
  /// @param prompt - Optional analysis instructions
  /// @param location - Optional location information
  /// @param province - Optional province information
  /// @param district - Optional district information
  /// @param neighborhood - Optional neighborhood information
  /// @param fieldName - Optional field name
  /// @return AnalysisResponse with results or error
  Future<AnalysisResponse> analyzePlant(
    Uint8List imageBytes,
    UserModel user, {
    String? prompt,
    String? location,
    String? province,
    String? district,
    String? neighborhood,
    String? fieldName,
  }) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        'Plant analysis started',
        'Image size: ${imageBytes.length} bytes, User: ${user.id}',
      );

      // === VALIDATION PHASE ===

      // 1. Basic user validation
      final userValidationResult = await _validateUser(user);
      if (!userValidationResult.success) {
        return userValidationResult;
      }

      // 2. Network connectivity check
      final connectivityValidationResult = await _validateConnectivity();
      if (!connectivityValidationResult.success) {
        return connectivityValidationResult;
      }

      // 3. User credits validation
      final creditValidationResult = await _validateUserCredits(user.id);
      if (!creditValidationResult.success) {
        return creditValidationResult;
      }

      // === ANALYSIS PHASE ===

      // 4. Prepare location information
      final String locationInfo = _prepareLocationInfo(
        location: location,
        province: province,
        district: district,
        neighborhood: neighborhood,
      );

      // 5. Perform AI analysis
      try {
        AppLogger.logWithContext(
          _serviceName,
          'Calling Gemini AI service',
          'Image size: ${imageBytes.length} bytes',
        );

        final analysisResult = await _geminiService.analyzeImage(
          imageBytes,
          prompt: prompt,
          location: locationInfo,
          province: province,
          district: district,
          neighborhood: neighborhood,
          fieldName: fieldName,
        );

        AppLogger.successWithContext(
          _serviceName,
          'AI analysis completed',
          'Response length: ${analysisResult.length} characters',
        );

        // 6. Update user credits
        await _updateUserCredits(user.id);

        // 7. Return successful response
        AppLogger.successWithContext(
          _serviceName,
          'Plant analysis completed successfully',
          'User: ${user.id}',
        );

        return AnalysisResponse(
          success: true,
          message: 'Analysis completed successfully',
          result: analysisResult,
          location: locationInfo,
          fieldName: fieldName,
          resultType: AnalysisServiceResultType.success,
        );
      } catch (geminiError) {
        AppLogger.errorWithContext(
          _serviceName,
          'Gemini AI service error',
          geminiError,
        );
        return _createErrorResponse(geminiError);
      }
    } catch (e, stackTrace) {
      return _handleGeneralError(e, stackTrace, 'Plant analysis general error');
    }
  }

  /// Gets disease advice without image analysis (Premium feature)
  ///
  /// @param diseaseName - Name of the disease
  /// @param user - User requesting advice
  /// @return AnalysisResponse with disease recommendations
  Future<AnalysisResponse> getDiseaseAdvice(
    String diseaseName,
    UserModel user,
  ) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        'Disease advice requested',
        'Disease: $diseaseName, User: ${user.id}',
      );

      // 1. Basic user validation
      final userValidationResult = await _validateUser(user);
      if (!userValidationResult.success) {
        return userValidationResult;
      }

      // 2. Premium access validation
      final premiumValidationResult = await _validateUserPremium(user.id);
      if (!premiumValidationResult.success) {
        return premiumValidationResult;
      }

      // 3. Get disease recommendations
      final recommendations = await _geminiService.getDiseaseRecommendations(
        diseaseName,
      );

      AppLogger.successWithContext(
        _serviceName,
        'Disease advice generated successfully',
        'User: ${user.id}, Disease: $diseaseName',
      );

      return AnalysisResponse(
        success: true,
        message: 'Disease recommendations retrieved successfully',
        result: recommendations,
        resultType: AnalysisServiceResultType.success,
      );
    } catch (e, stackTrace) {
      return _handleGeneralError(e, stackTrace, 'Disease advice error');
    }
  }

  /// Gets plant care advice without image analysis (Premium feature)
  ///
  /// @param plantName - Name of the plant
  /// @param user - User requesting advice
  /// @return AnalysisResponse with care recommendations
  Future<AnalysisResponse> getPlantCareAdvice(
    String plantName,
    UserModel user,
  ) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        'Plant care advice requested',
        'Plant: $plantName, User: ${user.id}',
      );

      // 1. Basic user validation
      final userValidationResult = await _validateUser(user);
      if (!userValidationResult.success) {
        return userValidationResult;
      }

      // 2. Premium access validation
      final premiumValidationResult = await _validateUserPremium(user.id);
      if (!premiumValidationResult.success) {
        return premiumValidationResult;
      }

      // 3. Get plant care advice
      final careAdvice = await _geminiService.getPlantCareAdvice(plantName);

      AppLogger.successWithContext(
        _serviceName,
        'Plant care advice generated successfully',
        'User: ${user.id}, Plant: $plantName',
      );

      return AnalysisResponse(
        success: true,
        message: 'Plant care recommendations retrieved successfully',
        result: careAdvice,
        resultType: AnalysisServiceResultType.success,
      );
    } catch (e, stackTrace) {
      return _handleGeneralError(e, stackTrace, 'Plant care advice error');
    }
  }

  /// Uploads image to Firebase Storage
  ///
  /// @param imageFile - Image file to upload
  /// @return Image download URL
  Future<String> uploadImage(File imageFile) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        'Uploading image to storage',
        'File path: ${imageFile.path}',
      );

      final fileName = 'analyses/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child(fileName);

      final uploadTask = await storageRef.putFile(imageFile);
      final imageUrl = await uploadTask.ref.getDownloadURL();

      AppLogger.successWithContext(
        _serviceName,
        'Image uploaded successfully',
        imageUrl,
      );

      return imageUrl;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Image upload error',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Analyzes image and returns structured result
  ///
  /// @param imageUrl - URL of uploaded image
  /// @param location - Location information
  /// @param fieldName - Optional field name
  /// @return PlantAnalysisResult with structured data
  Future<PlantAnalysisResult> analyzeImage({
    required String imageUrl,
    required String location,
    String? fieldName,
  }) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        'Analyzing image with structured response',
        'URL: $imageUrl',
      );

      // TODO: Integrate with actual AI analysis service
      // This is a placeholder implementation
      final analysisResult = PlantAnalysisResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        plantName: 'Sample Plant',
        probability: 0.95,
        isHealthy: true,
        diseases: [],
        description: 'This is a sample analysis result for development.',
        suggestions: [
          'Maintain regular watering schedule',
          'Provide adequate sunlight exposure',
          'Apply fertilizer weekly',
        ],
        imageUrl: imageUrl,
        similarImages: [],
        location: location,
        fieldName: fieldName,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      AppLogger.successWithContext(
        _serviceName,
        'Image analysis completed',
        'Plant: ${analysisResult.plantName}',
      );

      return analysisResult;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Image analysis error',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Converts file to byte array
  ///
  /// @param file - File to convert
  /// @return Byte array representation
  Future<Uint8List> fileToBytes(File file) async {
    try {
      AppLogger.logWithContext(
        _serviceName,
        'Converting file to bytes',
        'File: ${file.path}',
      );

      final bytes = await file.readAsBytes();

      AppLogger.successWithContext(
        _serviceName,
        'File converted to bytes',
        'Size: ${bytes.length} bytes',
      );

      return bytes;
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'File to bytes conversion error',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // PRIVATE VALIDATION METHODS
  // ============================================================================

  /// Validates user authentication
  ///
  /// @param user - User to validate
  /// @return AnalysisResponse indicating validation result
  Future<AnalysisResponse> _validateUser(UserModel user) async {
    try {
      // Basic user validation
      if (user.id.isEmpty) {
        AppLogger.warnWithContext(
          _serviceName,
          'Invalid user ID provided',
        );
        return AnalysisResponse(
          success: false,
          message: 'Invalid user authentication',
          resultType: AnalysisServiceResultType.userAuthError,
        );
      }

      // Check if user exists in Firestore
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.id)
          .get();

      if (!userDoc.exists) {
        AppLogger.warnWithContext(
          _serviceName,
          'User not found in database',
          user.id,
        );
        return AnalysisResponse(
          success: false,
          message: 'User not found',
          resultType: AnalysisServiceResultType.userAuthError,
        );
      }

      return AnalysisResponse(
        success: true,
        message: 'User validated successfully',
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'User validation error',
        e,
        stackTrace,
      );
      return AnalysisResponse(
        success: false,
        message: 'User validation failed',
        resultType: AnalysisServiceResultType.generalError,
      );
    }
  }

  /// Validates network connectivity
  ///
  /// @return AnalysisResponse indicating connectivity status
  Future<AnalysisResponse> _validateConnectivity() async {
    try {
      final connectivityValidation = await ValidationUtil.checkConnectivity();

      if (!connectivityValidation.isValid) {
        AppLogger.warnWithContext(
          _serviceName,
          'Network connectivity validation failed',
          connectivityValidation.message,
        );
        return AnalysisResponse(
          success: false,
          message:
              connectivityValidation.message ?? 'Network connectivity error',
          resultType: AnalysisServiceResultType.connectivityError,
        );
      }

      return AnalysisResponse(
        success: true,
        message: 'Network connectivity validated',
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Connectivity validation error',
        e,
        stackTrace,
      );
      return AnalysisResponse(
        success: false,
        message: 'Network connectivity check failed',
        resultType: AnalysisServiceResultType.connectivityError,
      );
    }
  }

  /// Validates user credits for analysis
  ///
  /// @param userId - User ID to check credits for
  /// @return AnalysisResponse indicating credit status
  Future<AnalysisResponse> _validateUserCredits(String userId) async {
    try {
      final creditValidation =
          await ValidationUtil.checkUserCreditsFromFirestore(
        userId,
        _firestore,
      );

      if (!creditValidation.isValid) {
        AppLogger.warnWithContext(
          _serviceName,
          'User credits validation failed',
          creditValidation.message,
        );
        return AnalysisResponse(
          success: false,
          message: creditValidation.message ?? 'Insufficient analysis credits',
          needsPremium: creditValidation.needsPremium,
          resultType: AnalysisServiceResultType.creditError,
        );
      }

      return AnalysisResponse(
        success: true,
        message: 'User credits validated',
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Credits validation error',
        e,
        stackTrace,
      );
      return AnalysisResponse(
        success: false,
        message: 'Credit validation failed',
        resultType: AnalysisServiceResultType.generalError,
      );
    }
  }

  /// Validates user premium subscription
  ///
  /// @param userId - User ID to check premium status
  /// @return AnalysisResponse indicating premium status
  Future<AnalysisResponse> _validateUserPremium(String userId) async {
    try {
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      final userData = userDoc.data();
      final bool isPremium = userData?['isPremium'] ?? false;

      if (!isPremium) {
        AppLogger.warnWithContext(
          _serviceName,
          'Non-premium user requested premium feature',
          userId,
        );
        return AnalysisResponse(
          success: false,
          message: 'This feature is available only for premium users',
          needsPremium: true,
          resultType: AnalysisServiceResultType.premiumRequired,
        );
      }

      return AnalysisResponse(
        success: true,
        message: 'Premium user validated',
      );
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Premium validation error',
        e,
        stackTrace,
      );
      return AnalysisResponse(
        success: false,
        message: 'Premium validation failed',
        resultType: AnalysisServiceResultType.generalError,
      );
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Updates user credits after successful analysis
  ///
  /// @param userId - User ID to update credits for
  Future<void> _updateUserCredits(String userId) async {
    try {
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      final userData = userDoc.data();
      final bool isPremium = userData?['isPremium'] ?? false;

      // Only deduct credits for non-premium users
      if (!isPremium) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .update({
          'analysisCredits': FieldValue.increment(-1),
        });

        final int currentCredits = userData?['analysisCredits'] ?? 0;
        final int remainingCredits = currentCredits - 1;

        AppLogger.successWithContext(
          _serviceName,
          'User credits updated',
          'Remaining credits: $remainingCredits',
        );
      } else {
        AppLogger.logWithContext(
          _serviceName,
          'Premium user - no credit deduction',
          userId,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.errorWithContext(
        _serviceName,
        'Credit update error',
        e,
        stackTrace,
      );
      // Don't throw error for credit update failures
      // Analysis was successful, credit update is secondary
    }
  }

  /// Prepares location information string
  ///
  /// @param location - Base location
  /// @param province - Province information
  /// @param district - District information
  /// @param neighborhood - Neighborhood information
  /// @return Formatted location string
  String _prepareLocationInfo({
    String? location,
    String? province,
    String? district,
    String? neighborhood,
  }) {
    final List<String> locationParts = [];

    // Build detailed location from administrative divisions
    if (province != null && province.isNotEmpty) {
      locationParts.add(province);

      if (district != null && district.isNotEmpty) {
        locationParts.add(district);

        if (neighborhood != null && neighborhood.isNotEmpty) {
          locationParts.add(neighborhood);
        }
      }
    }

    // Use detailed location if available, otherwise use provided location
    if (locationParts.isNotEmpty) {
      return locationParts.join('/');
    }

    if (location != null && location.isNotEmpty) {
      return location;
    }

    // Default location if nothing provided
    return 'Unknown Location';
  }

  /// Creates error response for API failures
  ///
  /// @param error - Error object from API
  /// @return AnalysisResponse with appropriate error details
  AnalysisResponse _createErrorResponse(dynamic error) {
    final String errorString = error.toString().toLowerCase();
    String errorMessage = 'Analysis error occurred';
    AnalysisServiceResultType resultType = AnalysisServiceResultType.apiError;

    // Categorize error based on content
    if (errorString.contains('api key') ||
        errorString.contains('api anahtarı')) {
      errorMessage =
          'API key error. Please try again later or contact support.';
    } else if (errorString.contains('network') ||
        errorString.contains('connection')) {
      errorMessage =
          'Network error. Please check your internet connection and try again.';
      resultType = AnalysisServiceResultType.connectivityError;
    } else if (errorString.contains('403') ||
        errorString.contains('unauthorized')) {
      errorMessage =
          'Authorization error. API access could not be established.';
    } else if (errorString.contains('timeout')) {
      errorMessage = 'Request timeout. Please try again.';
    } else {
      errorMessage =
          'Analysis service temporarily unavailable. Please try again later.';
    }

    return AnalysisResponse(
      success: false,
      message: errorMessage,
      resultType: resultType,
    );
  }

  /// Handles general errors with logging
  ///
  /// @param error - Error object
  /// @param stackTrace - Stack trace for debugging
  /// @param context - Error context description
  /// @return AnalysisResponse with error details
  AnalysisResponse _handleGeneralError(
    dynamic error,
    StackTrace stackTrace,
    String context,
  ) {
    AppLogger.errorWithContext(
      _serviceName,
      context,
      error,
      stackTrace,
    );

    // Truncate error message for user display
    final String errorMessage = error.toString();
    final String truncatedMessage = errorMessage.length > 100
        ? '${errorMessage.substring(0, 100)}...'
        : errorMessage;

    return AnalysisResponse(
      success: false,
      message: 'Operation failed: $truncatedMessage',
      resultType: AnalysisServiceResultType.generalError,
    );
  }
}

// ============================================================================
// ANALYSIS RESPONSE MODEL
// ============================================================================

/// Analysis Response Model
///
/// Represents the response from plant analysis operations.
/// Contains success status, user message, results, and metadata.
class AnalysisResponse {
  /// Whether the operation was successful
  final bool success;

  /// User-friendly message describing the result
  final String message;

  /// Analysis result content (if successful)
  final String? result;

  /// Whether premium subscription is required
  final bool needsPremium;

  /// Location information used in analysis
  final String? location;

  /// Field name used in analysis
  final String? fieldName;

  /// Type of result for categorization
  final AnalysisServiceResultType? resultType;

  /// Creates an AnalysisResponse
  ///
  /// @param success - Operation success status
  /// @param message - User-friendly message
  /// @param result - Analysis result content
  /// @param needsPremium - Premium requirement flag
  /// @param location - Location information
  /// @param fieldName - Field name
  /// @param resultType - Result type classification
  const AnalysisResponse({
    required this.success,
    required this.message,
    this.result,
    this.needsPremium = false,
    this.location,
    this.fieldName,
    this.resultType,
  });

  /// Creates a successful response
  ///
  /// @param message - Success message
  /// @param result - Analysis result
  /// @param location - Location information
  /// @param fieldName - Field name
  /// @return AnalysisResponse with success status
  factory AnalysisResponse.success({
    required String message,
    String? result,
    String? location,
    String? fieldName,
  }) {
    return AnalysisResponse(
      success: true,
      message: message,
      result: result,
      location: location,
      fieldName: fieldName,
      resultType: AnalysisServiceResultType.success,
    );
  }

  /// Creates an error response
  ///
  /// @param message - Error message
  /// @param resultType - Error type
  /// @param needsPremium - Premium requirement flag
  /// @return AnalysisResponse with error status
  factory AnalysisResponse.error({
    required String message,
    required AnalysisServiceResultType resultType,
    bool needsPremium = false,
  }) {
    return AnalysisResponse(
      success: false,
      message: message,
      resultType: resultType,
      needsPremium: needsPremium,
    );
  }

  @override
  String toString() {
    return 'AnalysisResponse(success: $success, message: $message, resultType: $resultType)';
  }
}
