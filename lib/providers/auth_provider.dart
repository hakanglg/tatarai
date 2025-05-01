import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  User? get currentUser => _auth.currentUser;

  // Kullanıcı giriş durumunu kontrol eder
  bool get isLoggedIn => _auth.currentUser != null;

  // Kullanıcı girişi yapar
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Kullanıcı kaydı yapar
  Future<UserCredential> register({
    required String email,
    required String password,
    required String name,
    required String surname,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Kullanıcı profil bilgilerini günceller
      await userCredential.user?.updateDisplayName('$name $surname');

      return userCredential;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Kullanıcı çıkışı yapar
  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Şifre sıfırlama e-postası gönderir
  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
