import 'package:flutter_test/flutter_test.dart';
import 'package:hot_wheels_safn/services/hot_wheels_wiki_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_wiki.dart';

void main() {
  test('search merges results, keeps thumbnails and puts series pages last', () async {
    final api = HotWheelsWikiApi(client: fakeWikiClient(withThumbnails: true));
    final results = await api.search('bone');

    expect(results.map((r) => r.title), ['Bone Shaker', '2006 First Editions']);
    expect(results.first.thumbnailUrl, 'https://img.test/Bone_Shaker.png');
  });

  test('search shows production years so similar castings can be told apart', () async {
    final api = HotWheelsWikiApi(client: fakeWikiClient());
    final results = await api.search('nissan 300zx');

    expect(results.map((r) => r.title), ['Nissan 300ZX', 'Nissan 300ZX Twin Turbo']);
    expect(results.map((r) => r.yearsText), ['1985 – 1996', '2019 – í dag']);
    expect(results.every((r) => r.isCasting), isTrue);
  });

  test('pages without a casting infobox are marked and listed last', () async {
    final api = HotWheelsWikiApi(client: fakeWikiClient());
    final results = await api.search('bone');

    expect(results.first.isCasting, isTrue);
    expect(results.first.yearsText, '2006 – í dag');
    expect(results.last.title, '2006 First Editions');
    expect(results.last.isCasting, isFalse);
    expect(results.last.yearsText, isNull);
  });

  test('empty search does not hit the network', () async {
    final log = <Uri>[];
    final api = HotWheelsWikiApi(client: fakeWikiClient(log: log));
    expect(await api.search('  '), isEmpty);
    expect(log, isEmpty);
  });

  test('fetchCasting parses the page and resolves all photos in batches', () async {
    final log = <Uri>[];
    final api = HotWheelsWikiApi(client: fakeWikiClient(log: log));
    final casting = await api.fetchCasting('Bone Shaker');

    expect(casting.name, 'Bone Shaker');
    expect(casting.imageUrl, 'https://img.test/Bone Shaker Sketch Larry Wood.png');
    expect(casting.versions.first.photoUrl, 'https://img.test/FE 5sp.jpg');
    expect(casting.versions.where((v) => v.photoFile != null && v.photoUrl == null), isEmpty);

    final imageRequests = log.where((u) => u.queryParameters['prop'] == 'imageinfo').toList();
    expect(imageRequests.length, greaterThan(1));
    for (final r in imageRequests) {
      expect(r.queryParameters['titles']!.split('|').length, lessThanOrEqualTo(50));
      expect(r.queryParameters['origin'], '*');
    }
  });

  test('missing page gives a friendly error', () async {
    final api = HotWheelsWikiApi(client: fakeWikiClient());
    expect(
      () => api.fetchCasting('Does Not Exist'),
      throwsA(isA<WikiApiException>().having((e) => e.message, 'message', contains('Fann ekki'))),
    );
  });

  test('server and network errors become WikiApiException', () async {
    final failing = HotWheelsWikiApi(client: MockClient((_) async => http.Response('oops', 503)));
    expect(() => failing.search('x'), throwsA(isA<WikiApiException>()));

    final offline = HotWheelsWikiApi(
      client: MockClient((_) async => throw http.ClientException('no network')),
    );
    expect(
      () => offline.fetchCasting('Bone Shaker'),
      throwsA(isA<WikiApiException>().having((e) => e.message, 'message', contains('netinu'))),
    );
  });
}
