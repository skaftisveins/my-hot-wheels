import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/casting.dart';
import 'wikitext_parser.dart';

class WikiApiException implements Exception {
  const WikiApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Tenging við Hot Wheels Wiki (hotwheels.fandom.com) í gegnum MediaWiki API.
///
/// Ekki þarf API-lykil. Gögnin á wiki-inu eru skrifuð af safnurum og gefin
/// út undir CC BY-SA leyfi.
class HotWheelsWikiApi {
  HotWheelsWikiApi({http.Client? client}) : _client = client ?? http.Client();

  static const host = 'hotwheels.fandom.com';
  static const _timeout = Duration(seconds: 20);
  static const _imageWidth = 500;
  static const _thumbWidth = 200;

  final http.Client _client;

  /// Leitar að bílum eftir nafni. Skilar fyrst niðurstöðum þar sem nafnið
  /// byrjar á leitarorðinu og svo öðrum sem passa.
  Future<List<WikiSearchResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final common = {
      'prop': 'pageimages',
      'piprop': 'thumbnail',
      'pithumbsize': '$_thumbWidth',
      'redirects': '1',
    };
    final results = await Future.wait([
      _get({
        ...common,
        'action': 'query',
        'generator': 'prefixsearch',
        'gpssearch': q,
        'gpslimit': '12',
        'gpsnamespace': '0',
      }),
      _get({
        ...common,
        'action': 'query',
        'generator': 'search',
        'gsrsearch': q,
        'gsrlimit': '20',
        'gsrnamespace': '0',
      }),
    ]);

    final seen = <String>{};
    final merged = <WikiSearchResult>[];
    for (final json in results) {
      for (final page in _sortedPages(json)) {
        final title = page['title'] as String;
        if (!seen.add(title)) continue;
        final thumb = page['thumbnail'] as Map<String, dynamic>?;
        merged.add(WikiSearchResult(title: title, thumbnailUrl: thumb?['source'] as String?));
      }
    }

    // Síður um heilar seríur og lista ("2024 HW Dream Garage", "List of ...")
    // eru sjaldnast það sem leitað er að, svo þær fara aftast.
    bool looksLikeList(String t) =>
        RegExp(r'^(19|20)\d{2} ').hasMatch(t) || t.startsWith('List of');
    final cars = merged.where((r) => !looksLikeList(r.title));
    final lists = merged.where((r) => looksLikeList(r.title));
    return [...cars, ...lists];
  }

  /// Sækir allar upplýsingar um einn bíl ásamt öllum útgáfum hans og myndum.
  Future<Casting> fetchCasting(String title) async {
    final json = await _get({
      'action': 'parse',
      'page': title,
      'prop': 'wikitext',
      'redirects': '1',
    });
    final parse = json['parse'] as Map<String, dynamic>?;
    if (parse == null) {
      throw const WikiApiException('Fann ekki þessa síðu á Hot Wheels Wiki.');
    }
    final casting = WikitextParser.parseCasting(
      parse['title'] as String? ?? title,
      parse['wikitext'] as String? ?? '',
    );

    final files = <String>{?casting.imageFile, for (final v in casting.versions) ?v.photoFile};
    final urls = await imageUrls(files);

    return casting.copyWith(
      imageUrl: urls[casting.imageFile],
      versions: [for (final v in casting.versions) v.withPhotoUrl(urls[v.photoFile])],
    );
  }

  /// Breytir skráarnöfnum mynda (t.d. „FE 5sp.jpg“) í slóðir á myndirnar.
  Future<Map<String, String>> imageUrls(Iterable<String> fileNames) async {
    final names = fileNames.where((n) => n.isNotEmpty).toSet().toList();
    final result = <String, String>{};
    const batchSize = 50; // hámark MediaWiki fyrir eina fyrirspurn

    final batches = [
      for (var i = 0; i < names.length; i += batchSize)
        names.sublist(i, (i + batchSize).clamp(0, names.length)),
    ];

    await Future.wait(
      batches.map((batch) async {
        try {
          final json = await _get({
            'action': 'query',
            'titles': batch.map((n) => 'File:$n').join('|'),
            'prop': 'imageinfo',
            'iiprop': 'url',
            'iiurlwidth': '$_imageWidth',
          });
          final query = json['query'] as Map<String, dynamic>? ?? const {};

          // MediaWiki getur breytt titlinum (t.d. „_“ í bil). Höldum utan um það.
          final renamed = <String, String>{};
          for (final n in (query['normalized'] as List? ?? const [])) {
            renamed[n['to'] as String] = n['from'] as String;
          }
          for (final page in (query['pages'] as List? ?? const [])) {
            final info = (page['imageinfo'] as List?)?.firstOrNull;
            if (info == null) continue;
            final url = (info['thumburl'] ?? info['url']) as String?;
            if (url == null) continue;
            final title = page['title'] as String;
            final requested = renamed[title] ?? title;
            result[requested.replaceFirst('File:', '')] = url;
            result[title.replaceFirst('File:', '')] = url;
          }
        } on WikiApiException {
          // Myndir eru aukaatriði; bíllinn er nothæfur án þeirra.
        }
      }),
    );
    return result;
  }

  List<Map<String, dynamic>> _sortedPages(Map<String, dynamic> json) {
    final pages =
        ((json['query'] as Map<String, dynamic>?)?['pages'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
    return [...pages]
      ..sort((a, b) => ((a['index'] as num?) ?? 0).compareTo((b['index'] as num?) ?? 0));
  }

  Future<Map<String, dynamic>> _get(Map<String, String> params) async {
    final uri = Uri.https(host, '/api.php', {
      ...params,
      'format': 'json',
      'formatversion': '2',
      // Leyfir fyrirspurnir úr vafra (CORS) þegar appið keyrir á vefnum.
      'origin': '*',
    });

    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: kIsWeb
                ? const {}
                : const {'User-Agent': 'HotWheelsSafn/1.0 (personal collection app)'},
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const WikiApiException('Tengingin tók of langan tíma. Reyndu aftur.');
    } catch (_) {
      throw const WikiApiException(
        'Náði ekki sambandi við Hot Wheels Wiki. Er tækið tengt netinu?',
      );
    }

    if (response.statusCode != 200) {
      throw WikiApiException('Hot Wheels Wiki svaraði með villu (${response.statusCode}).');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const WikiApiException('Fékk óskiljanlegt svar frá Hot Wheels Wiki.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const WikiApiException('Fékk óskiljanlegt svar frá Hot Wheels Wiki.');
    }
    final error = decoded['error'];
    if (error is Map && error['code'] == 'missingtitle') {
      throw const WikiApiException('Fann ekki þessa síðu á Hot Wheels Wiki.');
    }
    if (error != null) {
      throw WikiApiException('Villa frá Hot Wheels Wiki: ${error is Map ? error['info'] : error}');
    }
    return decoded;
  }

  void close() => _client.close();
}
