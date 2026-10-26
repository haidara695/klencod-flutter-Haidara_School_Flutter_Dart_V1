import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Web config supplied by the project owner. Android needs google-services.json
/// and flutterfire configure to generate platform-specific options.
class FirebaseSetup {
  static FirebaseOptions get web => const FirebaseOptions(
    apiKey: 'AIzaSyCGynZ1Xi_wcP6f2fILWIZdNN2Q0TGGy-8',
    authDomain: 'madarasti.firebaseapp.com',
    projectId: 'madarasti',
    storageBucket: 'madarasti.firebasestorage.app',
    messagingSenderId: '158411975799',
    appId: '1:158411975799:web:1943fb6546c929af13ea72',
    measurementId: 'G-KQBKM7FF6F',
  );
  static Future<void> initialize() async {
    if (kIsWeb) {
      await Firebase.initializeApp(options: web);
    } else {
      // Run flutterfire configure for Android/iOS; platform options must be
      // generated from the Firebase console, not fabricated from web settings.
      await Firebase.initializeApp();
    }
  }
}
