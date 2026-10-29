import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'env.dart';

/// Initialises Firebase from dart-defines when `USE_FIREBASE=true`, so the
/// app builds and runs without `google-services.json`. Returns whether
/// Firebase is ready.
Future<bool> initFirebase(AppEnv env) async {
  if (!env.useFirebase) return false;
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: env.firebaseApiKey,
        appId: env.firebaseAppId,
        messagingSenderId: env.firebaseSenderId,
        projectId: env.firebaseProjectId,
      ),
    );
    return true;
  } on Object catch (error) {
    debugPrint('Firebase initialisation failed: $error');
    return false;
  }
}

/// Whether Firebase was initialised. Overridden in `main()`.
final firebaseReadyProvider = Provider<bool>((ref) => false);
