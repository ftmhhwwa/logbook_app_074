class AccessPolicy {
  // Template ini mudah dikembangkan: tinggal tambah baris 'case' baru
  static bool canPerform(String role, String action, {bool isOwner = false}) {
    // Sovereignty rule: edit/hapus mutlak milik owner, terlepas dari role.
    if (['update', 'delete'].contains(action)) {
      return isOwner;
    }

    // Create/Read tetap diizinkan untuk role tim yang valid.
    if (['create', 'read'].contains(action)) {
      return role == 'Ketua' || role == 'Anggota';
    }

    return false;
  }
}
