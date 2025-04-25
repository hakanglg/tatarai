import 'package:dio/dio.dart';
import 'package:tatarai/core/utils/logger.dart';
import 'package:tatarai/features/plant_analysis/models/location_models.dart';

/// Service for fetching location data (provinces, districts, neighborhoods) from API
class LocationService {
  static const String _baseUrl = 'https://tradres.com.tr';
  final Dio _dio;

  LocationService({Dio? dio}) : _dio = dio ?? Dio();

  /// Get list of all provinces
  Future<List<Province>> getProvinces() async {
    try {
      final response = await _dio.get('$_baseUrl/api/iller');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final provinces = data.map((json) => Province.fromJson(json)).toList();
        AppLogger.i('${provinces.length} provinces loaded');
        return provinces;
      } else {
        throw Exception('Error loading provinces: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.e('Error loading provinces: $e');
      throw Exception('Error loading provinces: $e');
    }
  }

  /// Get districts for a selected province
  Future<List<District>> getDistricts(String provinceName) async {
    try {
      final encodedProvinceName =
          Uri.encodeComponent(provinceName.toLowerCase());
      final response =
          await _dio.get('$_baseUrl/api/ilceler?iladi=$encodedProvinceName');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final districts = data.map((json) => District.fromJson(json)).toList();
        AppLogger.i('${districts.length} districts loaded for $provinceName');
        return districts;
      } else {
        throw Exception('Error loading districts: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.e('Error loading districts: $e');
      throw Exception('Error loading districts: $e');
    }
  }

  /// Get neighborhoods for a selected province and district
  Future<List<Neighborhood>> getNeighborhoods(
      String provinceName, String districtName) async {
    try {
      final encodedProvinceName =
          Uri.encodeComponent(provinceName.toLowerCase());
      final encodedDistrictName = Uri.encodeComponent(districtName);
      final response = await _dio.get(
          '$_baseUrl/api/mahalleler?iladi=$encodedProvinceName&ilce=$encodedDistrictName');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final neighborhoods =
            data.map((json) => Neighborhood.fromJson(json)).toList();
        AppLogger.i(
            '${neighborhoods.length} neighborhoods loaded for $provinceName - $districtName');
        return neighborhoods;
      } else {
        throw Exception('Error loading neighborhoods: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.e('Error loading neighborhoods: $e');
      throw Exception('Error loading neighborhoods: $e');
    }
  }
}
