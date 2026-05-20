import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:crisis_link/core/router.dart';
import 'package:crisis_link/theme/app_theme.dart';
import 'package:crisis_link/services/firestore_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using explicit options for Windows/Web/Desktop support.
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCZbKDf5XjTYCFrSC7pRtHUtctGoezkKos",
        appId: "1:243160288031:web:2f81ed50f63ba05e903e2a",
        messagingSenderId: "243160288031",
        projectId: "ciro-28820",
        storageBucket: "ciro-28820.firebasestorage.app",
        authDomain: "ciro-28820.firebaseapp.com",
      ),
    );
  } catch (e) {
    debugPrint("Firebase initialization checked: $e");
  }

  runApp(const ProviderScope(child: CrisisLinkApp()));
}

class CrisisLinkApp extends ConsumerWidget {
  const CrisisLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Seed dummy/demo data if the Firestore collection is currently empty
    ref
        .read(firestoreServiceProvider)
        .seedDemoData()
        .then((_) {
          debugPrint("Demo data seeding checked/completed successfully.");
        })
        .catchError((error) {
          debugPrint("Warning: Failed to seed demo data: $error");
        });

    return MaterialApp.router(
      title: 'BayMax',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
