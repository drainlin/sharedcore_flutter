import 'package:flutter/material.dart';
import 'package:sharedcore_flutter/sharedcore_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SharedCoreExampleApp(initialization: _initializeSharedCore()));
}

Future<String> _initializeSharedCore() async {
  final client = await SharedCore.configure(
    const SharedCoreConfiguration(
      baseUrl: 'https://example.invalid',
      appId: 'sharedcore-flutter-example',
    ),
  );
  final version = await SharedCore.version();
  final device = await client.device();
  return 'SharedCore Rust $version\n${device.platform} ${device.osVersion}';
}

/// Minimal application proving that the bundled Rust library can be loaded.
class SharedCoreExampleApp extends StatelessWidget {
  /// Creates the example application.
  const SharedCoreExampleApp({required this.initialization, super.key});

  /// Loads Rust, configures the singleton, and collects platform metadata.
  final Future<String> initialization;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('SharedCore Rust')),
        body: Center(
          child: FutureBuilder<String>(
            future: initialization,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Failed to load Rust: ${snapshot.error}');
              }
              return Text(
                snapshot.hasData ? snapshot.data! : 'Loading SharedCore Rust…',
              );
            },
          ),
        ),
      ),
    );
  }
}
