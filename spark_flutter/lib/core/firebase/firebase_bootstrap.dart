import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

const FirebaseOptions _iosFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyCRTIPsNNDJYOfYHbF31LJGGg465lp0_vA',
  appId: '1:432040764664:ios:6bf2edaa2f3777c0cf470d',
  messagingSenderId: '432040764664',
  projectId: 'spark-a5928',
  storageBucket: 'spark-a5928.firebasestorage.app',
);

Future<FirebaseApp> ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) {
    return Firebase.app();
  }

  if (Platform.isIOS) {
    return Firebase.initializeApp(options: _iosFirebaseOptions);
  }

  return Firebase.initializeApp();
}
