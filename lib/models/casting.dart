/// Leitarniðurstaða af Hot Wheels Wiki.
class WikiSearchResult {
  const WikiSearchResult({
    required this.title,
    this.thumbnailUrl,
    this.isCasting = true,
    this.yearsText,
  });

  final String title;
  final String? thumbnailUrl;

  /// `false` ef síðan er um seríu, lista eða annað en einn bíl.
  final bool isCasting;

  /// Framleiðsluár bílgerðarinnar, t.d. „2019 – í dag“.
  final String? yearsText;
}

/// Gerir framleiðsluár af wiki læsileg á íslensku: „2019 - Present“ -> „2019 – í dag“.
String? icelandicYears(String? years) => years
    ?.replaceAll(RegExp(r'\s*(?:-|&ndash;|–)\s*'), ' – ')
    .replaceAll(RegExp(r'\bPresent\b', caseSensitive: false), 'í dag');

/// Ein útgáfa af bíl eins og hún er skráð í töflu á wiki-síðunni
/// (ein lína í „Versions“ töflunni).
class CastingVersion {
  const CastingVersion({
    this.section,
    this.collectorNumber,
    this.year,
    this.yearText,
    this.series,
    this.seriesNumber,
    this.color,
    this.tampo,
    this.baseColor,
    this.windowColor,
    this.interiorColor,
    this.wheelType,
    this.toyNumber,
    this.country,
    this.notes,
    this.photoFile,
    this.photoUrl,
  });

  /// Kaflinn á síðunni sem taflan er í, t.d. „Open Roof Versions“.
  final String? section;
  final String? collectorNumber;
  final int? year;
  final String? yearText;
  final String? series;
  final String? seriesNumber;
  final String? color;
  final String? tampo;
  final String? baseColor;
  final String? windowColor;
  final String? interiorColor;
  final String? wheelType;
  final String? toyNumber;
  final String? country;
  final String? notes;

  /// Skráarnafn myndarinnar á wiki, t.d. „FE 5sp.jpg“.
  final String? photoFile;

  /// Slóð á myndina, sótt sérstaklega út frá [photoFile].
  final String? photoUrl;

  String get searchText => [
    yearText,
    series,
    seriesNumber,
    color,
    tampo,
    wheelType,
    toyNumber,
    collectorNumber,
    notes,
    section,
  ].whereType<String>().join(' ').toLowerCase();

  CastingVersion withPhotoUrl(String? url) => CastingVersion(
    section: section,
    collectorNumber: collectorNumber,
    year: year,
    yearText: yearText,
    series: series,
    seriesNumber: seriesNumber,
    color: color,
    tampo: tampo,
    baseColor: baseColor,
    windowColor: windowColor,
    interiorColor: interiorColor,
    wheelType: wheelType,
    toyNumber: toyNumber,
    country: country,
    notes: notes,
    photoFile: photoFile,
    photoUrl: url,
  );
}

/// Upplýsingar um eitt „casting“ (bílgerð) af Hot Wheels Wiki.
class Casting {
  const Casting({
    required this.title,
    required this.isCasting,
    this.name,
    this.designer,
    this.yearsText,
    this.series,
    this.toyNumber,
    this.imageFile,
    this.imageUrl,
    this.versions = const [],
  });

  /// Titill wiki-síðunnar.
  final String title;

  /// `false` ef síðan er ekki bílasíða (t.d. síða um seríu).
  final bool isCasting;

  final String? name;
  final String? designer;

  /// Framleiðsluár, t.d. „2006 - Present“.
  final String? yearsText;

  /// Serían sem bíllinn kom fyrst út í.
  final String? series;
  final String? toyNumber;
  final String? imageFile;
  final String? imageUrl;
  final List<CastingVersion> versions;

  String get displayName => name ?? title;

  /// Fyrsta árið sem bíllinn kom út, ef það finnst.
  int? get firstYear {
    final match = RegExp(r'\b(19|20)\d{2}\b').firstMatch(yearsText ?? '');
    return match == null ? null : int.parse(match.group(0)!);
  }

  Casting copyWith({String? imageUrl, List<CastingVersion>? versions}) => Casting(
    title: title,
    isCasting: isCasting,
    name: name,
    designer: designer,
    yearsText: yearsText,
    series: series,
    toyNumber: toyNumber,
    imageFile: imageFile,
    imageUrl: imageUrl ?? this.imageUrl,
    versions: versions ?? this.versions,
  );
}
