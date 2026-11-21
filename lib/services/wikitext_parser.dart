import '../models/casting.dart';

/// Les wikitexta af síðum á Hot Wheels Wiki og dregur út:
///  * upplýsingaboxið `{{casting|...}}` (nafn, hönnuður, ár, númer, mynd)
///  * töflurnar með öllum útgáfum bílsins (ár, sería, litur, felgur, ...)
class WikitextParser {
  const WikitextParser._();

  static Casting parseCasting(String title, String wikitext) {
    final infobox = _findTemplate(wikitext, 'casting');
    final fields = infobox == null ? <String, String>{} : _templateFields(infobox);
    final versions = parseVersions(wikitext);

    String? field(String key) {
      final value = fields[key];
      if (value == null) return null;
      final cleaned = cleanText(value);
      return cleaned.isEmpty ? null : cleaned;
    }

    final imageRaw = fields['image'];
    final imageFile = imageRaw == null ? null : normalizeFileName(cleanText(imageRaw));
    return Casting(
      title: title,
      isCasting: infobox != null || versions.isNotEmpty,
      name: field('name'),
      designer: field('designer'),
      yearsText: _joinLines(cleanLines(fields['years'] ?? ''), ', '),
      series: field('series'),
      toyNumber: field('number'),
      imageFile: (imageFile ?? '').isEmpty ? null : imageFile,
      versions: versions,
    );
  }

  /// `true` ef textinn inniheldur upplýsingabox fyrir bíl (`{{casting|...}}`).
  static bool hasCastingInfobox(String wikitext) => _findTemplate(wikitext, 'casting') != null;

  /// Finnur allar útgáfutöflur á síðunni.
  static List<CastingVersion> parseVersions(String wikitext) {
    final versions = <CastingVersion>[];
    String? section;
    _TableBuilder? table;

    for (final rawLine in wikitext.split('\n')) {
      final line = rawLine.trimRight();
      final trimmed = line.trimLeft();

      if (table == null) {
        final heading = _headingPattern.firstMatch(trimmed);
        if (heading != null) {
          section = cleanText(heading.group(2)!);
          continue;
        }
        if (trimmed.startsWith('{|')) {
          table = _TableBuilder();
        }
        continue;
      }

      if (trimmed.startsWith('{|')) {
        table.nestedDepth++;
        continue;
      }
      if (trimmed.startsWith('|}')) {
        if (table.nestedDepth > 0) {
          table.nestedDepth--;
          continue;
        }
        // „Code 3“ eru heimasmíðaðar breytingar, ekki útgáfur frá Mattel.
        if (!(section ?? '').toLowerCase().contains('code 3')) {
          versions.addAll(table.build(section));
        }
        table = null;
        continue;
      }
      if (table.nestedDepth > 0) continue;
      table.addLine(trimmed);
    }
    return versions;
  }

  /// Breytir wikitexta í hreinan texta á einni línu.
  static String cleanText(String input) => _joinLines(cleanLines(input), ' ') ?? '';

  /// Breytir wikitexta í hreinan texta, ein færsla fyrir hverja `<br>` línu.
  static List<String> cleanLines(String input) {
    var s = input;
    s = s.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    s = s.replaceAll(RegExp(r'<ref[^>]*/>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<ref[^>]*>.*?</ref>', caseSensitive: false, dotAll: true), '');
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    // Myndir og flokkar eiga ekki heima í textanum.
    s = s.replaceAll(
      RegExp(r'\[\[\s*(?:file|image|category)\s*:[^\]]*\]\]', caseSensitive: false),
      '',
    );
    // [[Síða|texti]] -> texti, [[Síða]] -> Síða
    s = s.replaceAllMapped(RegExp(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]'), (m) => m.group(1)!);
    // [http://slóð texti] -> texti
    s = s.replaceAllMapped(RegExp(r'\[(?:https?:)?//\S+\s+([^\]]*)\]'), (m) => m.group(1)!);
    // Sniðmát {{...}} (innstu fyrst)
    final template = RegExp(r'\{\{[^{}]*\}\}');
    while (template.hasMatch(s)) {
      s = s.replaceAll(template, '');
    }
    s = s.replaceAll(RegExp(r"'{2,}"), '');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    return s
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Gerir skráarnafn sambærilegt við það sem MediaWiki skilar.
  static String normalizeFileName(String raw) {
    var name = raw.trim().replaceAll('_', ' ');
    name = name.replaceFirst(RegExp(r'^(file|image)\s*:\s*', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }

  /// Fyrsta myndin í wikitexta, t.d. `[[File:abc.jpg|75px]]` -> `abc.jpg`.
  static String? firstImage(String wikitext) {
    final match = RegExp(
      r'\[\[\s*(?:file|image)\s*:\s*([^|\]]+)',
      caseSensitive: false,
    ).firstMatch(wikitext);
    if (match == null) return null;
    final name = normalizeFileName(match.group(1)!);
    if (name.isEmpty || name.toLowerCase().startsWith('image not available')) {
      return null;
    }
    return name;
  }

  static final _headingPattern = RegExp(r'^(={2,6})\s*(.*?)\s*\1\s*$');

  static String? _joinLines(List<String> lines, String separator) {
    final joined = lines.join(separator).trim();
    return joined.isEmpty ? null : joined;
  }

  /// Skilar innihaldi fyrsta sniðmátsins `{{name ...}}`, án slaufusviganna.
  static String? _findTemplate(String wikitext, String name) {
    final start = RegExp(
      r'\{\{\s*' + RegExp.escape(name) + r'\s*(\||\}\})',
      caseSensitive: false,
    ).firstMatch(wikitext);
    if (start == null) return null;

    var depth = 0;
    for (var i = start.start; i < wikitext.length - 1; i++) {
      final pair = wikitext.substring(i, i + 2);
      if (pair == '{{') {
        depth++;
        i++;
      } else if (pair == '}}') {
        depth--;
        i++;
        if (depth == 0) return wikitext.substring(start.start + 2, i - 1);
      }
    }
    return null;
  }

  static Map<String, String> _templateFields(String body) {
    final fields = <String, String>{};
    final parts = splitTopLevel(body, '|');
    for (final part in parts.skip(1)) {
      final eq = part.indexOf('=');
      if (eq < 0) continue;
      final key = part.substring(0, eq).trim().toLowerCase();
      fields[key] = part.substring(eq + 1).trim();
    }
    return fields;
  }

  /// Skiptir texta á [separator] nema þegar hann er inni í `[[ ]]` eða `{{ }}`.
  static List<String> splitTopLevel(String text, String separator) {
    final parts = <String>[];
    var depth = 0;
    var last = 0;
    var i = 0;
    while (i < text.length) {
      if (text.startsWith('[[', i) || text.startsWith('{{', i)) {
        depth++;
        i += 2;
        continue;
      }
      if ((text.startsWith(']]', i) || text.startsWith('}}', i)) && depth > 0) {
        depth--;
        i += 2;
        continue;
      }
      if (depth == 0 && text.startsWith(separator, i)) {
        parts.add(text.substring(last, i));
        i += separator.length;
        last = i;
        continue;
      }
      i++;
    }
    parts.add(text.substring(last));
    return parts;
  }
}

enum _Column {
  collectorNumber,
  year,
  series,
  color,
  tampo,
  baseColor,
  windowColor,
  interiorColor,
  wheelType,
  toyNumber,
  country,
  notes,
  photo,
  other,
}

_Column _columnFor(String header) {
  final h = header.toLowerCase();
  if (h.contains('interior')) return _Column.interiorColor;
  if (h.contains('window')) return _Column.windowColor;
  if (h.contains('base')) return _Column.baseColor;
  if (h.contains('wheel')) return _Column.wheelType;
  if (h.contains('tampo') || h.contains('sticker') || h.contains('deco')) {
    return _Column.tampo;
  }
  if (h.contains('color') || h.contains('colour')) return _Column.color;
  if (h.startsWith('col')) return _Column.collectorNumber;
  if (h.contains('year')) return _Column.year;
  if (h.contains('series')) return _Column.series;
  if (h.contains('toy') || h.contains('cast')) return _Column.toyNumber;
  if (h.contains('country')) return _Column.country;
  if (h.contains('note')) return _Column.notes;
  if (h.contains('photo') || h.contains('image') || h.contains('picture')) {
    return _Column.photo;
  }
  return _Column.other;
}

String? _orNull(String value) => value.isEmpty ? null : value;

class _Cell {
  _Cell(this.text, {this.rowspan = 1, this.colspan = 1, this.isHeader = false});

  String text;
  final int rowspan;
  final int colspan;
  final bool isHeader;
}

class _Carry {
  _Carry(this.text, this.remaining);

  final String text;
  int remaining;
}

class _TableBuilder {
  int nestedDepth = 0;
  final List<List<_Cell>> _rows = [];
  List<_Cell>? _current;

  static final _attributes = RegExp(r'''^\s*([a-zA-Z-]+\s*=\s*("[^"]*"|'[^']*'|[^\s|]+)\s*)+$''');

  void addLine(String line) {
    if (line.startsWith('|-')) {
      _current = null;
      return;
    }
    if (line.startsWith('|+')) return; // fyrirsögn töflu
    if (line.startsWith('!') || line.startsWith('|')) {
      final isHeader = line.startsWith('!');
      final body = line.substring(1);
      final separator = isHeader && body.contains('!!') ? '!!' : '||';
      for (final raw in WikitextParser.splitTopLevel(body, separator)) {
        _row().add(_parseCell(raw, isHeader));
      }
      return;
    }
    // Framhald af síðasta reit.
    final row = _current;
    if (row != null && row.isNotEmpty) row.last.text += '\n$line';
  }

  List<_Cell> _row() {
    final row = _current;
    if (row != null) return row;
    final created = <_Cell>[];
    _rows.add(created);
    return _current = created;
  }

  _Cell _parseCell(String raw, bool isHeader) {
    var text = raw;
    var attrs = '';
    final parts = WikitextParser.splitTopLevel(raw, '|');
    if (parts.length > 1 && _attributes.hasMatch(parts.first)) {
      attrs = parts.first;
      text = parts.skip(1).join('|');
    }
    int span(String name) {
      final m = RegExp('$name\\s*=\\s*["\']?(\\d+)').firstMatch(attrs);
      return m == null ? 1 : int.parse(m.group(1)!).clamp(1, 500);
    }

    return _Cell(
      text.trim(),
      rowspan: span('rowspan'),
      colspan: span('colspan'),
      isHeader: isHeader,
    );
  }

  List<CastingVersion> build(String? section) {
    final headerIndex = _rows.indexWhere((r) => r.isNotEmpty && r.every((c) => c.isHeader));
    if (headerIndex < 0) return const [];

    final columns = <_Column>[];
    for (final cell in _rows[headerIndex]) {
      final column = _columnFor(WikitextParser.cleanText(cell.text));
      for (var i = 0; i < cell.colspan; i++) {
        columns.add(column);
      }
    }
    if (!columns.contains(_Column.year) ||
        !(columns.contains(_Column.color) || columns.contains(_Column.series))) {
      return const [];
    }

    final carries = List<_Carry?>.filled(columns.length, null);
    final versions = <CastingVersion>[];

    for (final row in _rows.skip(headerIndex + 1)) {
      if (row.isEmpty || row.every((c) => c.isHeader)) continue;
      final values = List<String>.filled(columns.length, '');
      var col = 0;
      var cellIndex = 0;

      bool placeCarry() {
        final carry = col < carries.length ? carries[col] : null;
        if (carry == null || carry.remaining <= 0) return false;
        values[col] = carry.text;
        carry.remaining--;
        col++;
        return true;
      }

      while (col < columns.length) {
        if (placeCarry()) continue;
        if (cellIndex >= row.length) {
          col++;
          continue;
        }
        final cell = row[cellIndex++];
        for (var i = 0; i < cell.colspan && col < columns.length; i++) {
          values[col] = cell.text;
          carries[col] = cell.rowspan > 1 ? _Carry(cell.text, cell.rowspan - 1) : null;
          col++;
        }
      }

      final version = _toVersion(columns, values, section);
      if (version != null) versions.add(version);
    }
    return versions;
  }

  CastingVersion? _toVersion(List<_Column> columns, List<String> values, String? section) {
    String? raw(_Column c) {
      final i = columns.indexOf(c);
      return i < 0 ? null : values[i];
    }

    String? text(_Column c) {
      final value = raw(c);
      if (value == null) return null;
      final cleaned = WikitextParser.cleanText(value);
      return cleaned.isEmpty ? null : cleaned;
    }

    final yearText = text(_Column.year);
    final seriesLines = WikitextParser.cleanLines(raw(_Column.series) ?? '');
    final color = text(_Column.color);
    if (yearText == null && color == null && seriesLines.isEmpty) return null;

    final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(yearText ?? '');
    final photoRaw = raw(_Column.photo);

    return CastingVersion(
      section: section,
      collectorNumber: text(_Column.collectorNumber),
      yearText: yearText,
      year: yearMatch == null ? null : int.parse(yearMatch.group(0)!),
      series: seriesLines.isEmpty ? null : seriesLines.first,
      seriesNumber: seriesLines.length > 1 ? seriesLines.skip(1).join(' ') : null,
      color: color,
      tampo: text(_Column.tampo),
      baseColor: text(_Column.baseColor),
      windowColor: text(_Column.windowColor),
      interiorColor: text(_Column.interiorColor),
      wheelType: text(_Column.wheelType),
      toyNumber: text(_Column.toyNumber),
      country: text(_Column.country),
      notes: _orNull(WikitextParser.cleanLines(raw(_Column.notes) ?? '').join(' · ')),
      photoFile: photoRaw == null ? null : WikitextParser.firstImage(photoRaw),
    );
  }
}
