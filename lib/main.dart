import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/collection_store.dart';
import 'services/hot_wheels_wiki_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(BilasafnApp(store: CollectionStore(prefs), api: HotWheelsWikiApi()));
}
