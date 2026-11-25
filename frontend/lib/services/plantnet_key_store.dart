import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Stores the player's own PlantNet API key.
///
/// No key is bundled with the app. A key can come from:
///  1. the in-app dialog (saved on the device), or
///  2. a build-time define: `flutter run --dart-define=PLANTNET_API_KEY=...`
class PlantNetKeyStore {
  PlantNetKeyStore._();

  static const _kPrefsKey = 'plantnet_api_key';
  static const _buildTimeKey = String.fromEnvironment('PLANTNET_API_KEY');
  static final Uri signUpUrl = Uri.parse('https://my.plantnet.org/');

  static Future<String?> getKey() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefsKey)?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
    return _buildTimeKey.isEmpty ? null : _buildTimeKey;
  }

  static Future<void> setKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = key?.trim() ?? '';
    if (trimmed.isEmpty) {
      await prefs.remove(_kPrefsKey);
    } else {
      await prefs.setString(_kPrefsKey, trimmed);
    }
  }

  /// Shows a dialog to enter / change the key. Returns the saved key, or
  /// `null` if the user cancelled or cleared it.
  static Future<String?> showKeyDialog(BuildContext context) async {
    final controller = TextEditingController(text: await getKey() ?? '');
    if (!context.mounted) return null;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F12),
        title: const Text('PlantNet API key',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The plant scanner uses PlantNet. Create a free account, '
                'copy your API key from your PlantNet profile, and paste it here. '
                'It is stored only on this device.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              TextButton.icon(
                onPressed: () => launchUrl(signUpUrl,
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Get a free key at my.plantnet.org'),
              ),
              TextField(
                controller: controller,
                autocorrect: false,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Paste your API key',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return null;
    await setKey(result);
    return getKey();
  }
}
