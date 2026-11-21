import 'package:flutter_test/flutter_test.dart';
import 'package:hot_wheels_safn/data/collection_store.dart';
import 'package:hot_wheels_safn/models/car.dart';
import 'package:shared_preferences/shared_preferences.dart';

Car car(
  String id,
  String name, {
  int? year,
  String? color,
  bool favorite = false,
  CarCondition condition = CarCondition.loose,
  int quantity = 1,
  DateTime? addedAt,
  String? casting,
}) => Car(
  id: id,
  name: name,
  year: year,
  color: color,
  favorite: favorite,
  condition: condition,
  quantity: quantity,
  castingTitle: casting,
  addedAt: addedAt ?? DateTime(2026, 1, int.parse(id)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Car survives a JSON round trip', () {
    final original = Car(
      id: 'a',
      name: 'Bone Shaker',
      addedAt: DateTime(2026, 11, 21, 10, 30),
      castingTitle: 'Bone Shaker',
      year: 2024,
      series: 'HW Dream Garage',
      seriesNumber: '3/5',
      color: 'Black',
      condition: CarCondition.carded,
      quantity: 3,
      favorite: true,
      notes: 'Afmælisgjöf',
    );
    final copy = Car.fromJson(original.toJson());
    expect(copy.toJson(), original.toJson());
    expect(copy.wikiUrl.toString(), 'https://hotwheels.fandom.com/wiki/Bone_Shaker');
  });

  test('persists cars between app starts', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = CollectionStore(prefs);
    await store.add(car('1', 'Twin Mill', year: 2020));
    await store.add(car('2', 'Bone Shaker', year: 2006));

    final reopened = CollectionStore(prefs);
    expect(reopened.cars.map((c) => c.name), ['Twin Mill', 'Bone Shaker']);
  });

  test('keeps unreadable data as a backup instead of overwriting it', () async {
    SharedPreferences.setMockInitialValues({'cars_v1': 'not json'});
    final prefs = await SharedPreferences.getInstance();
    final store = CollectionStore(prefs);
    expect(store.cars, isEmpty);
    expect(prefs.getKeys().where((k) => k.startsWith('cars_v1_backup_')), hasLength(1));
  });

  test('stats count copies, models and favorites', () async {
    final store = CollectionStore(await SharedPreferences.getInstance());
    await store.add(car('1', 'Twin Mill', year: 2020, quantity: 2, casting: 'Twin Mill'));
    await store.add(car('2', 'Twin Mill', year: 1999, casting: 'Twin Mill', favorite: true));
    await store.add(car('3', 'Bone Shaker'));

    expect(store.totalCars, 4);
    expect(store.distinctModels, 2);
    expect(store.favoriteCount, 1);
    expect(store.oldestYear, 1999);
    expect(store.sameModel('Twin Mill', 'Twin Mill'), hasLength(2));
  });

  test('query searches, filters and sorts', () async {
    final store = CollectionStore(await SharedPreferences.getInstance());
    await store.add(car('1', 'Twin Mill', year: 2020, color: 'Red'));
    await store.add(
      car(
        '2',
        'Bone Shaker',
        year: 2006,
        color: 'Black',
        favorite: true,
        condition: CarCondition.carded,
      ),
    );
    await store.add(car('3', 'Deora II', color: 'Red'));

    List<String> names(List<Car> cars) => cars.map((c) => c.name).toList();

    expect(names(store.query()), ['Deora II', 'Bone Shaker', 'Twin Mill']);
    expect(names(store.query(sort: CarSort.name)), ['Bone Shaker', 'Deora II', 'Twin Mill']);
    expect(names(store.query(sort: CarSort.yearOldest)), ['Bone Shaker', 'Twin Mill', 'Deora II']);
    expect(names(store.query(sort: CarSort.yearNewest)), ['Twin Mill', 'Bone Shaker', 'Deora II']);
    expect(names(store.query(search: 'red')), ['Deora II', 'Twin Mill']);
    expect(names(store.query(search: 'red 2020')), ['Twin Mill']);
    expect(names(store.query(filter: CarFilter.favorites)), ['Bone Shaker']);
    expect(names(store.query(filter: CarFilter.carded)), ['Bone Shaker']);
    expect(names(store.query(filter: CarFilter.loose)), ['Deora II', 'Twin Mill']);
  });

  test('update, quantity, favorite, remove and restore', () async {
    final store = CollectionStore(await SharedPreferences.getInstance());
    final twinMill = car('1', 'Twin Mill');
    await store.add(twinMill);

    await store.setQuantity('1', 3);
    await store.toggleFavorite('1');
    expect(store.byId('1')!.quantity, 3);
    expect(store.byId('1')!.favorite, isTrue);

    await store.setQuantity('1', 0); // ignored
    expect(store.byId('1')!.quantity, 3);

    await store.update(store.byId('1')!.copyWith(color: 'Blue'));
    expect(store.byId('1')!.color, 'Blue');

    final removed = store.byId('1')!;
    await store.remove('1');
    expect(store.cars, isEmpty);
    await store.restore(removed);
    expect(store.byId('1')!.color, 'Blue');
  });

  test('newId gives unique ids', () {
    final ids = List.generate(500, (_) => CollectionStore.newId());
    expect(ids.toSet(), hasLength(500));
  });
}
