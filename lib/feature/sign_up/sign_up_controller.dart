import 'package:any_docs/core/constant/url_constant.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SignUpController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;

  Future<void> signUp() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    isLoading.value = true;
    var shouldResetLoading = true;

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = credential.user;
      await user?.updateDisplayName(nameController.text.trim());

      await _auth.signOut();

      shouldResetLoading = false;
      isLoading.value = false;
      Get.offAllNamed(RouteConstant.LOGIN);
      Get.snackbar(
        'Account created',
        'Please login with your new account.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } on FirebaseAuthException catch (error) {
      Get.snackbar(
        'Sign up failed',
        _authErrorMessage(error),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } catch (_) {
      Get.snackbar(
        'Sign up failed',
        'Something went wrong. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    } finally {
      if (shouldResetLoading && !isClosed) {
        isLoading.value = false;
      }
    }
  }

  void togglePasswordVisibility() {
    isPasswordVisible.toggle();
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.toggle();
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password sign up is not enabled in Firebase.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      default:
        return error.message ?? 'Unable to create account. Please try again.';
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
