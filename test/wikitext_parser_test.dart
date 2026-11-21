import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hot_wheels_safn/services/wikitext_parser.dart';

String fixture(String name) => File('test/fixtures/$name.wikitext').readAsStringSync();

void main() {
  group('parseCasting', () {
    test('reads the casting infobox', () {
      final casting = WikitextParser.parseCasting('Bone Shaker', fixture('bone_shaker'));

      expect(casting.isCasting, isTrue);
      expect(casting.name, 'Bone Shaker');
      expect(casting.designer, 'Larry Wood');
      expect(casting.yearsText, '2006 - Present');
      expect(casting.firstYear, 2006);
      expect(casting.series, '2006 First Editions');
      expect(casting.toyNumber, 'J3247');
      expect(casting.imageFile, 'Bone Shaker Sketch Larry Wood.png');
    });

    test('joins multi-line years and handles multi-line infobox', () {
      final casting = WikitextParser.parseCasting('Rodger Dodger', fixture('rodger_dodger'));

      expect(casting.name, 'Rodger Dodger');
      expect(casting.series, 'Flying Colors');
      expect(casting.toyNumber, '8259');
      expect(
        casting.yearsText,
        '1974 - 1979 (original), 1998 - 2013 (1st retool), 2015 - Present (2nd retool)',
      );
    });

    test('reads every version row, expanding rowspans', () {
      final casting = WikitextParser.parseCasting('Bone Shaker', fixture('bone_shaker'));
      final versions = casting.versions;

      expect(versions.length, greaterThan(150));
      final first = versions[0];
      expect(first.section, 'Open Roof Versions');
      expect(first.collectorNumber, '006/223');
      expect(first.year, 2006);
      expect(first.series, '2006 First Editions');
      expect(first.seriesNumber, '6/38');
      expect(first.color, 'Black');
      expect(first.tampo, 'White Skull & Crossbones');
      expect(first.baseColor, 'Unpainted / Metal');
      expect(first.interiorColor, 'Dark Chrome');
      expect(first.wheelType, '5SP');
      expect(first.toyNumber, 'J3247');
      expect(first.country, 'Malaysia');
      expect(first.photoFile, 'FE 5sp.jpg');

      // Second row shares most cells with the first through rowspan="2".
      final second = versions[1];
      expect(second.collectorNumber, '006/223');
      expect(second.color, 'Black');
      expect(second.interiorColor, 'Chrome');
      expect(second.wheelType, 'FTE');
      expect(second.photoFile, 'Boneshaker-BBB01.jpg');
    });

    test('skips Code 3 sections and placeholder images', () {
      for (final name in ['bone_shaker', 'chevy_gasser']) {
        final casting = WikitextParser.parseCasting(name, fixture(name));
        expect(
          casting.versions.where((v) => (v.section ?? '').toLowerCase().contains('code 3')),
          isEmpty,
        );
        expect(
          casting.versions.where((v) => (v.photoFile ?? '').startsWith('Image Not Available')),
          isEmpty,
        );
      }
    });

    test('maps alternative column names (Cast#, no collector column)', () {
      final casting = WikitextParser.parseCasting('Rodger Dodger', fixture('rodger_dodger'));
      final first = casting.versions.first;

      expect(first.collectorNumber, isNull);
      expect(first.year, 1974);
      expect(first.toyNumber, '8259');
      expect(first.color, 'Enamel Plum');
      expect(first.wheelType, 'RL');
      expect(casting.versions.every((v) => v.year != null), isTrue);
    });

    test('a page without infobox or version tables is not a casting', () {
      final casting = WikitextParser.parseCasting(
        '2024 HW Dream Garage',
        "'''HW Dream Garage''' is a series.\n{| class=\"wikitable\"\n! Name !! Toy #\n|-\n| Car || ABC\n|}",
      );
      expect(casting.isCasting, isFalse);
      expect(casting.versions, isEmpty);
    });

    test('parses inline || cells and header !! cells', () {
      final versions = WikitextParser.parseVersions(
        '==Versions==\n'
        '{|\n'
        '! Year !! Series !! Color !! Photo\n'
        '|-\n'
        '| [[2020]] || [[HW Flames|Flames]]<br>3/10 || Red || [[File:Red_car.jpg|75px]]\n'
        '|-\n'
        '| 2021 || Mainline || Blue<ref>source</ref> ||\n'
        '|}',
      );
      expect(versions, hasLength(2));
      expect(versions[0].year, 2020);
      expect(versions[0].series, 'Flames');
      expect(versions[0].seriesNumber, '3/10');
      expect(versions[0].photoFile, 'Red car.jpg');
      expect(versions[1].color, 'Blue');
      expect(versions[1].photoFile, isNull);
    });
  });

  group('cleanText', () {
    test('removes wiki markup', () {
      expect(
        WikitextParser.cleanText("'''[[ZAMAC|Unpainted<br>/<br>Metal]]''' {{tpl|x}}&amp; more"),
        'Unpainted / Metal & more',
      );
      expect(WikitextParser.cleanText('[http://example.com Example site]'), 'Example site');
      expect(WikitextParser.cleanText('<!-- hidden -->Visible'), 'Visible');
    });
  });
}
