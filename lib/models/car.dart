/// Hvernig bíllinn er geymdur: enn í pakkningunni eða laus til að leika með.
enum CarCondition {
  loose('Laus'),
  carded('Í pakkningu');

  const CarCondition(this.label);

  final String label;

  static CarCondition fromName(String? name) =>
      CarCondition.values.firstWhere((c) => c.name == name, orElse: () => CarCondition.loose);
}

/// Einn bíll í safninu.
class Car {
  const Car({
    required this.id,
    required this.name,
    required this.addedAt,
    this.castingTitle,
    this.year,
    this.series,
    this.seriesNumber,
    this.collectorNumber,
    this.color,
    this.tampo,
    this.wheelType,
    this.toyNumber,
    this.baseColor,
    this.windowColor,
    this.interiorColor,
    this.country,
    this.designer,
    this.imageUrl,
    this.condition = CarCondition.loose,
    this.quantity = 1,
    this.favorite = false,
    this.notes,
  });

  final String id;

  /// Nafn bílsins (casting), t.d. „Bone Shaker“.
  final String name;

  /// Titill síðunnar á Hot Wheels Wiki, ef bíllinn var sóttur þaðan.
  final String? castingTitle;

  final int? year;
  final String? series;

  /// Númer innan seríunnar, t.d. „6/38“.
  final String? seriesNumber;

  /// Safnnúmer á pakkningunni, t.d. „006/223“.
  final String? collectorNumber;

  final String? color;
  final String? tampo;
  final String? wheelType;
  final String? toyNumber;
  final String? baseColor;
  final String? windowColor;
  final String? interiorColor;
  final String? country;
  final String? designer;
  final String? imageUrl;
  final CarCondition condition;

  /// Hversu mörg eintök af nákvæmlega þessum bíl eru til.
  final int quantity;
  final bool favorite;
  final String? notes;
  final DateTime addedAt;

  Uri? get wikiUrl => castingTitle == null
      ? null
      : Uri.https('hotwheels.fandom.com', '/wiki/${castingTitle!.replaceAll(' ', '_')}');

  /// Allur texti sem leitað er í þegar leitað er í safninu.
  String get searchText => [
    name,
    year?.toString(),
    series,
    color,
    tampo,
    wheelType,
    toyNumber,
    collectorNumber,
    designer,
    notes,
  ].whereType<String>().join(' ').toLowerCase();

  Car copyWith({
    String? name,
    String? castingTitle,
    int? year,
    String? series,
    String? seriesNumber,
    String? collectorNumber,
    String? color,
    String? tampo,
    String? wheelType,
    String? toyNumber,
    String? baseColor,
    String? windowColor,
    String? interiorColor,
    String? country,
    String? designer,
    String? imageUrl,
    CarCondition? condition,
    int? quantity,
    bool? favorite,
    String? notes,
  }) {
    return Car(
      id: id,
      addedAt: addedAt,
      name: name ?? this.name,
      castingTitle: castingTitle ?? this.castingTitle,
      year: year ?? this.year,
      series: series ?? this.series,
      seriesNumber: seriesNumber ?? this.seriesNumber,
      collectorNumber: collectorNumber ?? this.collectorNumber,
      color: color ?? this.color,
      tampo: tampo ?? this.tampo,
      wheelType: wheelType ?? this.wheelType,
      toyNumber: toyNumber ?? this.toyNumber,
      baseColor: baseColor ?? this.baseColor,
      windowColor: windowColor ?? this.windowColor,
      interiorColor: interiorColor ?? this.interiorColor,
      country: country ?? this.country,
      designer: designer ?? this.designer,
      imageUrl: imageUrl ?? this.imageUrl,
      condition: condition ?? this.condition,
      quantity: quantity ?? this.quantity,
      favorite: favorite ?? this.favorite,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'addedAt': addedAt.toIso8601String(),
    'castingTitle': castingTitle,
    'year': year,
    'series': series,
    'seriesNumber': seriesNumber,
    'collectorNumber': collectorNumber,
    'color': color,
    'tampo': tampo,
    'wheelType': wheelType,
    'toyNumber': toyNumber,
    'baseColor': baseColor,
    'windowColor': windowColor,
    'interiorColor': interiorColor,
    'country': country,
    'designer': designer,
    'imageUrl': imageUrl,
    'condition': condition.name,
    'quantity': quantity,
    'favorite': favorite,
    'notes': notes,
  }..removeWhere((_, value) => value == null);

  factory Car.fromJson(Map<String, dynamic> json) => Car(
    id: json['id'] as String,
    name: json['name'] as String,
    addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
    castingTitle: json['castingTitle'] as String?,
    year: (json['year'] as num?)?.toInt(),
    series: json['series'] as String?,
    seriesNumber: json['seriesNumber'] as String?,
    collectorNumber: json['collectorNumber'] as String?,
    color: json['color'] as String?,
    tampo: json['tampo'] as String?,
    wheelType: json['wheelType'] as String?,
    toyNumber: json['toyNumber'] as String?,
    baseColor: json['baseColor'] as String?,
    windowColor: json['windowColor'] as String?,
    interiorColor: json['interiorColor'] as String?,
    country: json['country'] as String?,
    designer: json['designer'] as String?,
    imageUrl: json['imageUrl'] as String?,
    condition: CarCondition.fromName(json['condition'] as String?),
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    favorite: json['favorite'] as bool? ?? false,
    notes: json['notes'] as String?,
  );
}
