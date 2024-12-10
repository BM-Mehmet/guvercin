import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:guvercin/load_page/load.dart';
import 'package:guvercin/register/register.dart';
import 'firebase_options.dart';

void main() async {
  // Uygulama başlatılmadan önce Firebase'i başlatıyoruz.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseApi().initNotifications();

  // Firebase başarıyla başlatıldıktan sonra uygulamayı başlatıyoruz.
  runApp(
const LoadPage()); // RegisterPage widget'ını uygulama olarak başlatıyoruz.
}
