import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'services/audio_service.dart';
import 'services/storage_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/studio_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Immersive Studio Dark styling for status bar & navigation bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: StudioTheme.bgDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storage = await StorageService.init();
  final api = ApiService(storage);
  final audio = LiveAudioService();

  runApp(HighriseStudioApp(
    storage: storage,
    api: api,
    audio: audio,
  ));
}

class HighriseStudioApp extends StatelessWidget {
  final StorageService storage;
  final ApiService api;
  final LiveAudioService audio;

  const HighriseStudioApp({
    super.key,
    required this.storage,
    required this.api,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    final hasSession = storage.hasCredentials();

    return MaterialApp(
      title: 'Highrise Studio',
      debugShowCheckedModeBanner: false,
      theme: StudioTheme.darkTheme,
      home: hasSession
          ? MainNavigationScreen(
              storage: storage,
              api: api,
              audioService: audio,
            )
          : LoginScreen(
              storage: storage,
              api: api,
            ),
    );
  }
}
