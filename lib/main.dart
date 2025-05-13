import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:guvercin/load_page/load.dart';
import 'package:guvercin/account/register/register.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseApi().initNotifications();
  runApp(
const LoadPage()); 
} 