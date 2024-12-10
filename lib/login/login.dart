import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(LoginPage());
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Güvercin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center( // Bu satır, tüm öğelerin merkezde konumlanmasını sağlar.
        child: Padding(
          padding: const EdgeInsets.all(32.0), // Padding'i iki katına çıkardık
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Dikeyde merkeze alır
            crossAxisAlignment: CrossAxisAlignment.center, // Yatayda merkeze alır
            children: [
              // Güvercin logosu
              Image.asset(
                'lib/img/Logo.png',  // Burada logonun yolunu belirtin
                height: 160,          // Logonun yüksekliğini iki katına çıkardık
                width: 160,           // Logonun genişliğini iki katına çıkardık
              ),
              const SizedBox(height: 40), // Boşluk boyutunu iki katına çıkardık

              // Kullanıcı adı ve şifre formunu bir container içinde kutucuk olarak gösterme
              Container(
                padding: const EdgeInsets.all(24),  // İçerideki elemanlar için daha büyük boşluk
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30), // Köşe yuvarlama miktarını artırdık
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 6), // Gölgeyi biraz daha büyüttük
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  maxWidth: 600, // Container'ın genişliğini artırdık
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Kullanıcı adı (otomatik olarak atanacak)
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          prefixIcon: Icon(Icons.person, size: 32), // Icon boyutunu iki katına çıkardık
                          labelStyle: TextStyle(fontSize: 24), // Etiket yazı boyutunu artırdık
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Kullanıcı adı boş olamaz!';
                          }
                          return null;
                        },
                        style: const TextStyle(fontSize: 24), // Giriş kutusu yazı boyutunu artırdık
                      ),
                      const SizedBox(height: 24), // Daha fazla boşluk

                      // Şifre
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: Icon(Icons.lock, size: 32), // Icon boyutunu iki katına çıkardık
                          labelStyle: TextStyle(fontSize: 24), // Etiket yazı boyutunu artırdık
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifre boş olamaz!';
                          }
                          return null;
                        },
                        style: const TextStyle(fontSize: 24), // Giriş kutusu yazı boyutunu artırdık
                      ),
                      const SizedBox(height: 24), // Daha fazla boşluk

                      // Giriş butonu
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            // Giriş işlemi
                            String username = _usernameController.text;
                            String password = _passwordController.text;
                            
                            // Giriş işlemine yönlendirilebilir.
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Giriş başarılı!')));
                            
                            // Burada Firebase veya başka bir API ile giriş yapılabilir.
                            // Örneğin:
                            // loginUser(username, password);
                          }
                        }, // Buton yazı boyutunu artırdık
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20), // Buton padding'ini artırdık
                          textStyle: const TextStyle(fontSize: 24),  // Buton yazı fontunu büyüttük
                        ),
                        child: Text('Giriş Yap', style: TextStyle(fontSize: 28)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
