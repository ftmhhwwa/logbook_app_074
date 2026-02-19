// login_view.dart
import 'package:flutter/material.dart';
// Import Controller milik sendiri (masih satu folder)
import 'package:logbook_app_001/features/auth/login_controller.dart';
// Import View dari fitur lain (Logbook) untuk navigasi
import 'package:logbook_app_001/features/logbook/counter_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // Inisialisasi Otak dan Controller Input
  final LoginController _controller = LoginController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isPasswordHidden = true;
  int _failedAttempts = 0;
  bool _isLoginDisabled = false;
  int _disableCountdown = 0;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _startLoginCooldown() {
    setState(() {
      _isLoginDisabled = true;
      _disableCountdown = 10;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) {
        return false;
      }
      setState(() {
        _disableCountdown -= 1;
      });
      if (_disableCountdown <= 0) {
        setState(() {
          _isLoginDisabled = false;
          _failedAttempts = 0;
        });
        return false;
      }
      return true;
    });
  }

  void _handleLogin() {
    String user = _userController.text;
    String pass = _passController.text;

    if (user.isEmpty || pass.isEmpty) {
      _showSnackBar("Username dan Password tidak boleh kosong");
      return;
    }

    bool isSuccess = _controller.login(user, pass);

    if (isSuccess) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          // Di sini kita kirimkan variabel 'user' ke parameter 'username' di CounterView
          builder: (context) => CounterView(username: user),
        ),
      );
    } else {
      _failedAttempts += 1;
      _showSnackBar("Login Gagal! Periksa username dan password");
      if (_failedAttempts >= 3 && !_isLoginDisabled) {
        _startLoginCooldown();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login Gatekeeper")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            TextField(
              controller: _passController,
              obscureText: _isPasswordHidden,
              decoration: InputDecoration(
                labelText: "Password",
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordHidden ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() {
                    _isPasswordHidden = !_isPasswordHidden;
                  }),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoginDisabled ? null : _handleLogin,
              child: Text(
                _isLoginDisabled ? "Tunggu $_disableCountdown dtk" : "Masuk",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
