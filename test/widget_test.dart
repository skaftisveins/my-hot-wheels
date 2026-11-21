import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_wheels_safn/app.dart';
import 'package:hot_wheels_safn/data/collection_store.dart';
import 'package:hot_wheels_safn/models/car.dart';
import 'package:hot_wheels_safn/screens/add_car_search_screen.dart';
import 'package:hot_wheels_safn/screens/casting_screen.dart';
import 'package:hot_wheels_safn/services/hot_wheels_wiki_api.dart';
import 'package:hot_wheels_safn/services/photo_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_wiki.dart';

Future<CollectionStore> pumpApp(WidgetTester tester, {List<Car> cars = const []}) async {
  SharedPreferences.setMockInitialValues({});
  PhotoStore.instance = MemoryPhotoStore();
  final store = CollectionStore(await SharedPreferences.getInstance());
  for (final car in cars) {
    await store.add(car);
  }
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    BilasafnApp(
      store: store,
      api: HotWheelsWikiApi(client: fakeWikiClient()),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

/// Scrolls the version list on the casting screen until [label] shows up, then taps it.
Future<void> tapVersion(WidgetTester tester, String label) async {
  final target = find.descendant(of: find.byType(CastingScreen), matching: find.text(label));
  final list = find.descendant(
    of: find.byType(CastingScreen),
    matching: find.byType(CustomScrollView),
  );
  for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty collection invites to add the first car', (tester) async {
    await pumpApp(tester);
    expect(find.text('Bílskúrinn er tómur'), findsOneWidget);
    expect(find.text('Skrá fyrsta bílinn'), findsOneWidget);
  });

  testWidgets('register a car from the wiki: search, pick version, save', (tester) async {
    final store = await pumpApp(tester);

    await tester.tap(find.text('Skrá bíl'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bone');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Bone Shaker'), findsOneWidget);
    expect(find.text('Framleiddur 2006 – í dag'), findsOneWidget);
    expect(find.text('2006 First Editions'), findsOneWidget);
    expect(find.text('Sería, listi eða annað'), findsOneWidget);

    await tester.tap(find.text('Bone Shaker'));
    await tester.pumpAndSettle();
    expect(find.text('Hönnuður: Larry Wood'), findsOneWidget);
    expect(find.text('Hvaða útgáfu ertu með?'), findsOneWidget);

    // Narrow down to the very first release and pick it.
    await tester.enterText(find.byType(TextField), '2006 first editions black');
    await tester.pumpAndSettle();
    await tapVersion(tester, '2006 · Black');

    expect(find.text('Nýr bíll'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Bone Shaker'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '2006'), findsOneWidget);

    await tester.tap(find.text('Setja í safnið'));
    await tester.pumpAndSettle();

    expect(store.cars, hasLength(1));
    final car = store.cars.single;
    expect(car.name, 'Bone Shaker');
    expect(car.castingTitle, 'Bone Shaker');
    expect(car.year, 2006);
    expect(car.color, 'Black');
    expect(car.series, '2006 First Editions');
    expect(car.imageUrl, startsWith('https://img.test/'));

    // Back on the collection screen with the new car.
    expect(find.text('Bílasafnið'), findsWidgets);
    expect(find.text('2006 · Black'), findsOneWidget);
  });

  testWidgets('register a car manually', (tester) async {
    final store = await pumpApp(tester);

    await tester.tap(find.text('Skrá bíl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finnurðu ekki bílinn? Skráðu hann handvirkt'));
    await tester.pumpAndSettle();

    // Name is required.
    await tester.tap(find.text('Setja í safnið'));
    await tester.pumpAndSettle();
    expect(find.text('Bíllinn þarf að heita eitthvað'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nafn bílsins *'), 'Lögreglubíll');
    await tester.enterText(find.widgetWithText(TextFormField, 'Árgerð'), '2025');
    await tester.tap(find.text('Í pakkningu'));
    await tester.tap(find.text('Setja í safnið'));
    await tester.pumpAndSettle();

    expect(store.cars.single.name, 'Lögreglubíll');
    expect(store.cars.single.year, 2025);
    expect(store.cars.single.condition, CarCondition.carded);
  });

  testWidgets('manual registration offers to take a photo', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Skrá bíl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finnurðu ekki bílinn? Skráðu hann handvirkt'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Taka mynd af bílnum'));
    await tester.pumpAndSettle();
    expect(find.text('Settu bílinn á hvítt blað eða ljósan, sléttan flöt.'), findsOneWidget);
    expect(find.text('Taka mynd'), findsOneWidget);
    expect(find.text('Velja úr myndasafni'), findsOneWidget);
  });

  testWidgets('the showroom menu can switch back to the wiki photo', (tester) async {
    final store = await pumpApp(
      tester,
      cars: [
        Car(
          id: 'a',
          name: 'Twin Mill',
          imageUrl: 'https://img.test/a.png',
          ownPhoto: 'p1',
          addedAt: DateTime(2026),
        ),
      ],
    );
    await tester.tap(find.text('Twin Mill'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Meira'));
    await tester.pumpAndSettle();
    expect(find.text('Taka mynd af bílnum'), findsOneWidget);
    await tester.tap(find.text('Nota wiki-myndina'));
    await tester.pumpAndSettle();
    expect(store.byId('a')!.ownPhoto, isNull);
  });

  testWidgets('warns about duplicates and can add a copy instead', (tester) async {
    final store = await pumpApp(
      tester,
      cars: [
        Car(
          id: 'x',
          name: 'Bone Shaker',
          castingTitle: 'Bone Shaker',
          year: 2006,
          color: 'Black',
          addedAt: DateTime(2026),
        ),
      ],
    );

    await tester.tap(find.text('Skrá bíl'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bone');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AddCarSearchScreen), matching: find.text('Bone Shaker')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Þú átt nú þegar 1 svona bíl'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '2006 first editions black');
    await tester.pumpAndSettle();
    await tapVersion(tester, '2006 · Black');

    expect(find.text('Þú átt þennan bíl nú þegar!'), findsOneWidget);
    await tester.tap(find.textContaining('Bæta við eintaki'));
    await tester.pumpAndSettle();

    expect(store.cars, hasLength(1));
    expect(store.cars.single.quantity, 2);
  });

  testWidgets('flip through the collection and filter favorites', (tester) async {
    final store = await pumpApp(
      tester,
      cars: [
        Car(id: 'a', name: 'Twin Mill', year: 2020, addedAt: DateTime(2026, 1, 1)),
        Car(id: 'b', name: 'Deora II', favorite: true, addedAt: DateTime(2026, 1, 2)),
        Car(id: 'c', name: 'Rodger Dodger', addedAt: DateTime(2026, 1, 3)),
      ],
    );
    expect(find.text('3'), findsWidgets); // stats

    // Newest first: Rodger Dodger, Deora II, Twin Mill.
    await tester.tap(find.text('Rodger Dodger'));
    await tester.pumpAndSettle();
    expect(find.text('1 af 3'), findsOneWidget);

    // Arrow keys flip on keyboards (web/tablet).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('2 af 3'), findsOneWidget);
    expect(find.text('Deora II'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-600, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('3 af 3'), findsOneWidget);
    expect(find.text('Twin Mill'), findsOneWidget);

    // Tapping the stage hides everything but the car, tapping again brings it back.
    double captionOpacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: find.text('Twin Mill'), matching: find.byType(AnimatedOpacity)).first,
        )
        .opacity;
    expect(captionOpacity(), 1);
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 400)); // past the double-tap window
    await tester.pumpAndSettle();
    expect(captionOpacity(), 0);
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(captionOpacity(), 1);

    // Details live in a sheet.
    await tester.tap(find.text('Nánar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fjölga eintökum'));
    await tester.pumpAndSettle();
    expect(store.byId('a')!.quantity, 2);
    expect(find.text('2 eintök'), findsOneWidget);
    await tester.tapAt(const Offset(200, 40)); // close the sheet
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(PageView))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Uppáhalds'));
    await tester.pumpAndSettle();
    expect(find.text('Deora II'), findsOneWidget);
    expect(find.text('Twin Mill'), findsNothing);
  });

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('a slow ${kind.name} drag flips to the next car', (tester) async {
      await pumpApp(
        tester,
        cars: [
          Car(id: 'a', name: 'Twin Mill', addedAt: DateTime(2026, 1, 1)),
          Car(id: 'b', name: 'Deora II', addedAt: DateTime(2026, 1, 2)),
        ],
      );
      await tester.tap(find.text('Deora II'));
      await tester.pumpAndSettle();

      final drag = await tester.startGesture(const Offset(380, 400), kind: kind);
      for (var i = 0; i < 25; i++) {
        await drag.moveBy(const Offset(-12, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 200)); // let go slowly, no fling
      await drag.up();
      await tester.pumpAndSettle();
      expect(find.text('2 af 2'), findsOneWidget);
    });
  }

  testWidgets('double tap opens the photo zoom view, one tap closes it', (tester) async {
    await pumpApp(
      tester,
      cars: [
        Car(
          id: 'a',
          name: 'Twin Mill',
          imageUrl: 'https://img.test/a.png',
          addedAt: DateTime(2026),
        ),
      ],
    );
    await tester.tap(find.text('Twin Mill'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(216, 300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(216, 300));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Loka'), findsOneWidget);

    await tester.tap(find.byTooltip('Loka'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Loka'), findsNothing);
    expect(find.text('Twin Mill'), findsOneWidget);
  });

  testWidgets('slideshow plays through the cars and stops at the end', (tester) async {
    await pumpApp(
      tester,
      cars: [
        Car(id: 'a', name: 'Twin Mill', addedAt: DateTime(2026, 1, 1)),
        Car(id: 'b', name: 'Deora II', addedAt: DateTime(2026, 1, 2)),
      ],
    );
    await tester.tap(find.text('Deora II'));
    await tester.pumpAndSettle();
    expect(find.text('1 af 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Spila sýningu'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('2 af 2'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Spila sýningu'), findsOneWidget); // stopped, controls back
  });

  testWidgets('delete a car and undo', (tester) async {
    final store = await pumpApp(
      tester,
      cars: [Car(id: 'a', name: 'Twin Mill', addedAt: DateTime(2026))],
    );
    await tester.tap(find.text('Twin Mill'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eyða bíl'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eyða'));
    await tester.pumpAndSettle();

    expect(store.cars, isEmpty);
    expect(find.text('Bílskúrinn er tómur'), findsOneWidget);

    await tester.tap(find.text('Afturkalla'));
    await tester.pumpAndSettle();
    expect(store.cars, hasLength(1));
  });
}
