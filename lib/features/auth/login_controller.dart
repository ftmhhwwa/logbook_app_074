// login_controller.dart
class LoginController {
  // Database sederhana (Hardcoded)
  final Map<String, String> _users = {"admin": "123", "fatim": "123", "budi": "123"};

  // Fungsi pengecekan (Logic-Only)
  // Fungsi ini mengembalikan true jika cocok, false jika salah.
  bool login(String username, String password) {
    return _users[username] == password;
  }
}
