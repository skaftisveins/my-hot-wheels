import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/car.dart';

enum CarSort {
  newest('Nýjast skráð'),
  name('Nafn (A–Ö)'),
  yearNewest('Árgerð (nýjast)'),
  yearOldest('Árgerð (elst)');

  const CarSort(this.label);

  final String label;
}

enum CarFilter {
  all('Allir'),
  favorites('Uppáhalds'),
  carded('Í pakkningu'),
  loose('Lausir');

  const CarFilter(this.label);

  final String label;
}

/// Heldur utan um bílasafnið og vistar það á tækinu.
class CollectionStore extends ChangeNotifier {
  CollectionStore(this._prefs) {
    _load();
  }

  static const _storageKey = 'cars_v1';

  final SharedPreferences _prefs;
  List<Car> _cars = [];

  List<Car> get cars => List.unmodifiable(_cars);

  int get totalCars => _cars.fold(0, (sum, c) => sum + c.quantity);

  int get distinctModels => _cars.map((c) => c.castingTitle ?? c.name.toLowerCase()).toSet().length;

  int get favoriteCount => _cars.where((c) => c.favorite).length;

  int? get oldestYear {
    final years = _cars.map((c) => c.year).whereType<int>();
    return years.isEmpty ? null : years.reduce((a, b) => a < b ? a : b);
  }

  Car? byId(String id) => _cars.where((c) => c.id == id).firstOrNull;

  /// Bílar af sömu gerð sem eru þegar í safninu.
  List<Car> sameModel(String? castingTitle, String name) => _cars
      .where(
        (c) => castingTitle != null
            ? c.castingTitle == castingTitle
            : c.name.toLowerCase() == name.toLowerCase(),
      )
      .toList();

  List<Car> query({
    String search = '',
    CarFilter filter = CarFilter.all,
    CarSort sort = CarSort.newest,
  }) {
    final terms = search.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final result = _cars.where((car) {
      final passesFilter = switch (filter) {
        CarFilter.all => true,
        CarFilter.favorites => car.favorite,
        CarFilter.carded => car.condition == CarCondition.carded,
        CarFilter.loose => car.condition == CarCondition.loose,
      };
      if (!passesFilter) return false;
      final text = car.searchText;
      return terms.every(text.contains);
    }).toList();

    int byYear(Car a, Car b, {required bool newestFirst}) {
      final ya = a.year, yb = b.year;
      if (ya == null && yb == null) return 0;
      if (ya == null) return 1;
      if (yb == null) return -1;
      return newestFirst ? yb.compareTo(ya) : ya.compareTo(yb);
    }

    result.sort(switch (sort) {
      CarSort.newest => (a, b) => b.addedAt.compareTo(a.addedAt),
      CarSort.name => (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      CarSort.yearNewest => (a, b) => byYear(a, b, newestFirst: true),
      CarSort.yearOldest => (a, b) => byYear(a, b, newestFirst: false),
    });
    return result;
  }

  Future<void> add(Car car) async {
    _cars = [..._cars, car];
    await _save();
  }

  Future<void> update(Car car) async {
    _cars = [for (final c in _cars) c.id == car.id ? car : c];
    await _save();
  }

  Future<void> remove(String id) async {
    _cars = _cars.where((c) => c.id != id).toList();
    await _save();
  }

  /// Setur bíl aftur inn (t.d. þegar hætt er við eyðingu).
  Future<void> restore(Car car) async {
    if (byId(car.id) != null) return;
    await add(car);
  }

  Future<void> toggleFavorite(String id) async {
    final car = byId(id);
    if (car != null) await update(car.copyWith(favorite: !car.favorite));
  }

  Future<void> setQuantity(String id, int quantity) async {
    final car = byId(id);
    if (car != null && quantity >= 1) await update(car.copyWith(quantity: quantity));
  }

  static final _random = Random();

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(0x7fffffff).toRadixString(36)}';

  void _load() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _cars = list.map((e) => Car.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // Geymum skemmdu gögnin svo þau tapist ekki þegar næst er vistað.
      debugPrint('Gat ekki lesið safnið: $e');
      _prefs.setString('${_storageKey}_backup_${DateTime.now().millisecondsSinceEpoch}', raw);
    }
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs.setString(_storageKey, jsonEncode(_cars.map((c) => c.toJson()).toList()));
  }
}
