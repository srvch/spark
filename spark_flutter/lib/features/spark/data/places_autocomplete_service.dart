import 'package:dio/dio.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.primaryText,
    this.secondaryText,
    this.placeId,
  });

  final String primaryText;
  final String? secondaryText;
  final String? placeId;
}

class PlacesAutocompleteService {
  PlacesAutocompleteService({required String apiKey, Dio? dio})
      : _apiKey = apiKey,
        _dio = dio ?? Dio();

  final String _apiKey;
  final Dio _dio;

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<List<PlaceSuggestion>> search({
    required String input,
    String regionCode = 'IN',
    String languageCode = 'en',
  }) async {
    if (!isConfigured || input.trim().isEmpty) return const [];

    Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        'https://places.googleapis.com/v1/places:autocomplete',
        data: {
          'input': input.trim(),
          'regionCode': regionCode,
          'languageCode': languageCode,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask':
                'suggestions.placePrediction.placeId,'
                    'suggestions.placePrediction.structuredFormat.mainText.text,'
                    'suggestions.placePrediction.structuredFormat.secondaryText.text,'
                    'suggestions.placePrediction.text.text,'
                    'suggestions.queryPrediction.text.text',
          },
        ),
      );
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map<String, dynamic>
          ? ((body['error'] as Map<String, dynamic>?)?['message'] as String? ?? '')
          : '';
      final isNewApiDisabled = message.contains('Places API (New)') ||
          message.contains('SERVICE_DISABLED');
      if (isNewApiDisabled) {
        return _searchLegacy(
          input: input,
          regionCode: regionCode,
          languageCode: languageCode,
        );
      }
      rethrow;
    }

    final body = response.data ?? const <String, dynamic>{};
    final suggestions = (body['suggestions'] as List<dynamic>? ?? const []);
    final results = <PlaceSuggestion>[];

    for (final item in suggestions) {
      if (item is! Map<String, dynamic>) continue;
      final placePrediction = item['placePrediction'] as Map<String, dynamic>?;
      if (placePrediction != null) {
        final structured = placePrediction['structuredFormat'] as Map<String, dynamic>?;
        final main = (structured?['mainText'] as Map<String, dynamic>?)?['text'] as String?;
        final secondary =
            (structured?['secondaryText'] as Map<String, dynamic>?)?['text'] as String?;
        final text = (placePrediction['text'] as Map<String, dynamic>?)?['text'] as String?;
        final primary = (main ?? text ?? '').trim();
        if (primary.isEmpty) continue;
        results.add(
          PlaceSuggestion(
            primaryText: primary,
            secondaryText: secondary?.trim().isEmpty == true ? null : secondary?.trim(),
            placeId: placePrediction['placeId'] as String?,
          ),
        );
        continue;
      }

      final queryPrediction = item['queryPrediction'] as Map<String, dynamic>?;
      if (queryPrediction != null) {
        final text = (queryPrediction['text'] as Map<String, dynamic>?)?['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          results.add(PlaceSuggestion(primaryText: text.trim()));
        }
      }
    }

    return results;
  }

  Future<List<PlaceSuggestion>> _searchLegacy({
    required String input,
    required String regionCode,
    required String languageCode,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json',
      queryParameters: {
        'input': input.trim(),
        'key': _apiKey,
        'language': languageCode,
        'components': 'country:$regionCode',
      },
    );

    final body = response.data ?? const <String, dynamic>{};
    final status = (body['status'] as String?) ?? 'UNKNOWN_ERROR';
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      return const [];
    }

    final predictions = body['predictions'] as List<dynamic>? ?? const [];
    final results = <PlaceSuggestion>[];
    for (final item in predictions) {
      if (item is! Map<String, dynamic>) continue;
      final structured = item['structured_formatting'] as Map<String, dynamic>?;
      final primary = (structured?['main_text'] as String?) ??
          (item['description'] as String?) ??
          '';
      final secondary = structured?['secondary_text'] as String?;
      if (primary.trim().isEmpty) continue;
      results.add(
        PlaceSuggestion(
          primaryText: primary.trim(),
          secondaryText: secondary?.trim().isEmpty == true ? null : secondary?.trim(),
          placeId: item['place_id'] as String?,
        ),
      );
    }
    return results;
  }
}
