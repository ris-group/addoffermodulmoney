import 'dart:convert';
import 'package:http/http.dart' as http;
class AppService{


  Future<dynamic> fetchOffers() async {
    const url = 'https://api.leadgid.com/offers/v1/affiliates/offers';

    final params = {
      'lang': 'ru',
      'country[]': '296',
      'limit': '500',
    };

    // Headers
    final headers = {
      'accept': 'application/json',
      'X-ACCOUNT-TOKEN': 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzUxMiJ9.eyJpYXQiOjE3NDg3OTI3MjguOTU4Mzg2LCJpc3MiOiJhdXRoLmxlYWRnaWQiLCJleHAiOjMwMTEwOTY3MjguOTU4Mzg2LCJ0b2tlbl9pZCI6MTg5NjI0MywidXNlcl9pZCI6MTAzMzUzLCJ1c2VyX2VtYWlsIjoiQXBpZ2VuZXJhdGlvbkBtYWlsLnJ1IiwiYWNjb3VudF90eXBlIjoiYWZmaWxpYXRlIiwiYWNjb3VudF9pZCI6MTI3OTEyLCJmaXJzdF9uYW1lIjoi0JDQv9C4IiwibGFzdF9uYW1lIjoi0JjQvdGC0LXQs9GA0LDRhtC40Y8ifQ.P6ibjbwCX-viOgI-B7jb-k1PsWrM0MbHdKWu5fpXFWUn8YSiTy20DiaQqN5tf1fCzHUmHt0UOriwbb1Dxaf48bDQYzXrXdgLW6skQ2OO5Tzdqgqw8mAvMOKhOtSbHRsEyoBzm5W-981iWfeEVlp574Dh8Dw1XLx9PQ6kK2a2puwizmW86fOKW5lCPdK08qZ7FHCUUlunP3b7HYcYw0ak-_Ucpv-MPLggF-XXXD8qv48o-huXN_HowjbELWl7Oai2cw8lnGau9XyLQchIvkyFUielNovcwJn9RkmWLiwCSYlF8Uh93PeIir0zWtbMmwN2kDtnaj3ihtKJ-1vfA7gceQ',
    };

    try {
      final uri = Uri.parse(url).replace(queryParameters: params);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load offers');
      }
    } catch (e) {
      print('Exception: $e');
      throw Exception('Failed to make request: $e');
    }
  }
}