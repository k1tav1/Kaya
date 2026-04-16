import 'dart:convert';
import 'package:http/http.dart' as http;

class MarketService {
  MarketService._();

  static const String _apiKey = '770ff79b2232426da2dc9d8063f85317';
  static const String _baseUrl = 'https://api.twelvedata.com';

  static Future<Map<String, dynamic>> fetchLatestPrice({
    required String symbol,
    required String label,
    required String assetType,
    bool forceRefresh = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/price?symbol=$symbol&apikey=$_apiKey');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch price for $symbol');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['status'] == 'error') {
      throw Exception(data['message'] ?? 'Unknown market API error');
    }

    return {
      'symbol': symbol,
      'label': label,
      'assetType': assetType,
      'price': data['price']?.toString() ?? 'N/A',
    };
  }

  static Future<List<Map<String, dynamic>>> fetchTimeSeries({
    required String symbol,
    String interval = '1day',
    int outputSize = 7,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/time_series?symbol=$symbol&interval=$interval&outputsize=$outputSize&apikey=$_apiKey',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch chart data for $symbol');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['status'] == 'error') {
      throw Exception(data['message'] ?? 'Unknown chart API error');
    }

    final values = (data['values'] as List?) ?? [];

    return values
        .map<Map<String, dynamic>>((item) {
          return {
            'datetime': item['datetime'],
            'close': double.tryParse(item['close'].toString()) ?? 0.0,
          };
        })
        .toList()
        .reversed
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchMarketWatch({
    bool forceRefresh = false,
  }) async {
    final items = [
      {'symbol': 'BTC/USD', 'label': 'Bitcoin', 'assetType': 'crypto'},
      {'symbol': 'XAU/USD', 'label': 'Gold', 'assetType': 'commodity'},
    ];

    final results = <Map<String, dynamic>>[];

    for (final item in items) {
      try {
        final row = await fetchLatestPrice(
          symbol: item['symbol']!,
          label: item['label']!,
          assetType: item['assetType']!,
          forceRefresh: forceRefresh,
        );
        results.add(row);
      } catch (_) {
        results.add({
          'symbol': item['symbol'],
          'label': item['label'],
          'assetType': item['assetType'],
          'price': 'N/A',
        });
      }
    }

    return results;
  }
}
