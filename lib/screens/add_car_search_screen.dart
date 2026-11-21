import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../models/car.dart';
import '../models/casting.dart';
import '../services/hot_wheels_wiki_api.dart';
import '../widgets/car_image.dart';
import 'car_form_screen.dart';
import 'casting_screen.dart';

/// Fyrsta skrefið í skráningu: leitað að bílnum á Hot Wheels Wiki.
class AddCarSearchScreen extends StatefulWidget {
  const AddCarSearchScreen({super.key});

  @override
  State<AddCarSearchScreen> createState() => _AddCarSearchScreenState();
}

class _AddCarSearchScreenState extends State<AddCarSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  bool _loading = false;
  String? _error;
  List<WikiSearchResult>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      _requestId++;
      setState(() {
        _results = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await AppScope.apiOf(context).search(query);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on WikiApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _registerManually() {
    final name = _controller.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CarFormScreen(
          car: Car(id: '', name: name, addedAt: DateTime.now()),
          isNew: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;

    Widget body;
    if (_error != null) {
      body = _Message(
        icon: Icons.wifi_off_rounded,
        text: _error!,
        action: FilledButton.tonal(
          onPressed: () => _search(_controller.text),
          child: const Text('Reyna aftur'),
        ),
      );
    } else if (results == null) {
      body = const _Message(
        icon: Icons.manage_search_rounded,
        text:
            'Skrifaðu nafnið sem stendur á bílnum eða pakkningunni, '
            't.d. „Bone Shaker“, „Twin Mill“ eða „Skyline“.\n\n'
            'Nafnið er oft líka undir bílnum.',
      );
    } else if (results.isEmpty && !_loading) {
      body = const _Message(
        icon: Icons.search_off_rounded,
        text: 'Ekkert fannst. Prófaðu annað nafn eða skráðu bílinn handvirkt.',
      );
    } else {
      body = ListView.separated(
        itemCount: results.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 104),
        itemBuilder: (context, i) {
          final result = results[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 54,
                child: CarImage(url: result.thumbnailUrl, fit: BoxFit.cover, iconSize: 24),
              ),
            ),
            title: Text(result.title, style: theme.textTheme.titleMedium),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => CastingScreen(title: result.title))),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skrá bíl'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (v) {
                _debounce?.cancel();
                if (v.trim().isNotEmpty) _search(v);
              },
              decoration: InputDecoration(
                hintText: 'Hvaða bíll er þetta?',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: body,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: TextButton.icon(
            onPressed: _registerManually,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Finnurðu ekki bílinn? Skráðu hann handvirkt'),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
