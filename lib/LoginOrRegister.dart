import 'package:flutter/material.dart';
import 'LoginPage.dart'; // Updated import path
import 'SignUpPage.dart'; // Updated import path and file name

class LoginOrRegister extends StatefulWidget {
  const LoginOrRegister({super.key});

  @override
  State<LoginOrRegister> createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  // initially, show login page
  bool showLoginPage = true;

  // toggle between login and register page
  void togglePages() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      return LoginPage(onTap: togglePages);
    } else {
      return SignupPage(
        onTap: togglePages,
      ); // Changed from RegisterPage to SignupPage
    }
  }
}
