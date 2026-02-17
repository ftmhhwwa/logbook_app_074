import 'package:flutter/material.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  // Variabel state untuk melacak halaman onboarding
  int _step = 1;

  void _handleNext() {
    setState(() {
      if (_step < 3) {
        _step++;
      } else {
        // Pindah halaman menggunakan pushReplacement
        // Supaya user tidak bisa "back" lagi ke onboarding
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gambar atau Ikon (Opsional, agar visualnya bagus)
            Icon(Icons.auto_awesome, size: 100, color: Colors.teal.shade300),
            const SizedBox(height: 30),
            
            // Teks Dinamis berdasarkan Step
            Text(
              "Selamat Datang di LogBook! ($_step/3)",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: Text(
                "Catat setiap aktivitasmu dengan mudah dan efisien dalam satu aplikasi.",
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Tombol Navigasi
            ElevatedButton(
              onPressed: _handleNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: Text(_step == 3 ? "Mulai Sekarang" : "Selanjutnya"),
            ),
          ],
        ),
      ),
    );
  }
}