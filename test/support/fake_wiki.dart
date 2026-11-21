import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A fake Hot Wheels Wiki that answers like the real MediaWiki API.
MockClient fakeWikiClient({bool withThumbnails = false, List<Uri>? log}) {
  final pages = {
    'Bone Shaker': File('test/fixtures/bone_shaker.wikitext').readAsStringSync(),
    'Rodger Dodger': File('test/fixtures/rodger_dodger.wikitext').readAsStringSync(),
    // Tvær ólíkar gerðir með næstum sama nafni.
    'Nissan 300ZX':
        '{{casting\n|name = Nissan 300ZX\n|years = [[1985]] - [[1996]]\n|designer = [[Larry Wood]]}}\n'
        '==Versions==\n',
    'Nissan 300ZX Twin Turbo':
        '{{casting|name=Nissan 300ZX Twin Turbo|years=[[2019]] - Present|number=FYB73}}\n'
        '==Versions==\n',
  };
  const seriesIntro = "'''2006 First Editions''' is a series.\n{| class=\"wikitable\"\n|}";

  /// Fyrsti hluti síðunnar (á undan fyrstu fyrirsögn), eins og `rvsection=0` skilar.
  Map<String, dynamic> intro(String title) {
    final text = pages[title] ?? seriesIntro;
    final end = text.indexOf('\n==');
    return {
      'revisions': [
        {
          'slots': {
            'main': {'content': end < 0 ? text : text.substring(0, end)},
          },
        },
      ],
    };
  }

  http.Response json(Object body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  return MockClient((request) async {
    log?.add(request.url);
    final p = request.url.queryParameters;
    String? thumb(String title) =>
        withThumbnails ? 'https://img.test/${title.replaceAll(' ', '_')}.png' : null;

    if (p['action'] == 'query' && p['generator'] == 'prefixsearch') {
      final q = p['gpssearch']!.toLowerCase();
      final titles = pages.keys.where((t) => t.toLowerCase().startsWith(q)).toList();
      return json({
        'query': {
          'pages': [
            for (final (i, t) in titles.indexed)
              {
                'title': t,
                'index': i + 1,
                if (thumb(t) != null) 'thumbnail': {'source': thumb(t)},
                ...intro(t),
              },
          ],
        },
      });
    }
    if (p['action'] == 'query' && p['generator'] == 'search') {
      final q = p['gsrsearch']!.toLowerCase();
      final titles = [
        ...pages.keys.where((t) => t.toLowerCase().contains(q)),
        if (q.contains('bone')) '2006 First Editions',
      ];
      return json({
        'query': {
          'pages': [
            for (final (i, t) in titles.indexed) {'title': t, 'index': i + 1, ...intro(t)},
          ],
        },
      });
    }
    if (p['action'] == 'parse') {
      final title = p['page']!.replaceAll('_', ' ');
      final text = pages[title];
      if (text == null) {
        return json({
          'error': {'code': 'missingtitle', 'info': "The page you specified doesn't exist."},
        });
      }
      return json({
        'parse': {'title': title, 'wikitext': text},
      });
    }
    if (p['action'] == 'query' && p['prop'] == 'imageinfo') {
      final titles = p['titles']!.split('|');
      return json({
        'query': {
          'normalized': [
            for (final t in titles)
              if (t.contains('_')) {'from': t, 'to': t.replaceAll('_', ' ')},
          ],
          'pages': [
            for (final t in titles)
              {
                'title': t.replaceAll('_', ' '),
                'imageinfo': [
                  {'thumburl': 'https://img.test/${t.substring(5)}'},
                ],
              },
          ],
        },
      });
    }
    return http.Response('not found', 404);
  });
}
