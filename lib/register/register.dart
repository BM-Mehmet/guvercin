import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(RegisterPage());
}

class RegisterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Güvercin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: RegisterScreen(),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Kullanıcı adı otomatik olarak oluşturuluyor.
    _usernameController.text = _generateUniqueUsername();
  }

  // Rastgele benzersiz kullanıcı adı oluşturma fonksiyonu
  String _generateUniqueUsername() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    var random = Random();
    var username = '';
    
    // Kullanıcı adı için 6 karakter oluşturuyoruz (istediğiniz uzunlukta ayarlanabilir)
    for (int i = 0; i < 6; i++) {
      username += chars[random.nextInt(chars.length)];
    }
    
    return username;
  }

  // Şifre doğrulama fonksiyonu
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre boş olamaz!';
    }
    if (value != _confirmPasswordController.text) {
      return 'Şifreler uyuşmuyor!';
    }
    return null;
  }

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
              SizedBox(height: 40), // Boşluk boyutunu iki katına çıkardık

              // Kullanıcı adı ve şifre formunu bir container içinde kutucuk olarak gösterme
              Container(
                padding: EdgeInsets.all(24),  // İçerideki elemanlar için daha büyük boşluk
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30), // Köşe yuvarlama miktarını artırdık
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: Offset(0, 6), // Gölgeyi biraz daha büyüttük
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  maxWidth: 600, // Container'ın genişliğini artırdık
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Kullanıcı adı (otomatik olarak atanacak)
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
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
                        style: TextStyle(fontSize: 24), // Giriş kutusu yazı boyutunu artırdık
                      ),
                      SizedBox(height: 24), // Daha fazla boşluk

                      // Şifre
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: Icon(Icons.lock, size: 32), // Icon boyutunu iki katına çıkardık
                          labelStyle: TextStyle(fontSize: 24), // Etiket yazı boyutunu artırdık
                        ),
                        validator: (value) {
                          return _validatePassword(value);
                        },
                        style: TextStyle(fontSize: 24), // Giriş kutusu yazı boyutunu artırdık
                      ),
                      SizedBox(height: 24), // Daha fazla boşluk

                      // Şifre Tekrarı
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Şifreyi Tekrarla',
                          prefixIcon: Icon(Icons.lock, size: 32), // Icon boyutunu iki katına çıkardık
                          labelStyle: TextStyle(fontSize: 24), // Etiket yazı boyutunu artırdık
                        ),
                        validator: (value) {
                          return _validatePassword(value);
                        },
                        style: TextStyle(fontSize: 24), // Giriş kutusu yazı boyutunu artırdık
                      ),
                      SizedBox(height: 24), // Daha fazla boşluk

                      // Kayıt butonu
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            // Kayıt işlemi
                            String username = _usernameController.text;
                            String password = _passwordController.text;
                            
                            // Kayıt işlemine yönlendirilebilir.
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Kayıt başarılı!')));
                            
                            // Burada Firebase veya başka bir API ile kullanıcıyı kaydedebilirsiniz.
                            // Örneğin:
                            // registerUser(username, password);
                          }
                        },
                        child: Text('Kayıt Ol', style: TextStyle(fontSize: 28)), // Buton yazı boyutunu artırdık
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20), // Buton padding'ini artırdık
                          textStyle: TextStyle(fontSize: 24),  // Buton yazı fontunu büyüttük
                        ),
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
