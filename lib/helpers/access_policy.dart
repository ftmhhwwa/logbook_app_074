class AccessPolicy {
  // Template ini mudah dikembangkan: tinggal tambah baris 'case' baru
  static bool canPerform(String role, String action, {bool isOwner = false}) {
    switch (role) {
      case 'Ketua':
        return true; // Ketua bisa semua (Full CRUD)
      case 'Anggota':
        // Anggota bisa Create dan Read; Update/Delete hanya milik sendiri.
        if (['create', 'read'].contains(action)) {
          return true;
        }
        if (['update', 'delete'].contains(action)) {
          return isOwner;
        }
        return false;
      default:
        return false;
    }
  }
}
