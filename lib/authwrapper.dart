import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthWrapper extends StatefulWidget {
  final Widget child;

  const AuthWrapper({Key? key, required this.child}) : super(key: key);

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _supabase = Supabase.instance.client;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();

    // Слушаем изменения состояния авторизации
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;

      // Обрабатываем события входа и выхода
      if (event == AuthChangeEvent.signedIn) {
        _handleSignedIn();
      } else if (event == AuthChangeEvent.signedOut) {
        _handleSignedOut();
      }
    });
  }

  Future<void> _checkAuth() async {
    setState(() {
      _isChecking = true;
    });

    try {
      // Проверяем текущую сессию
      final session = _supabase.auth.currentSession;
      if (session == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } catch (e) {
      // При ошибке перенаправляем на страницу входа
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  void _handleSignedIn() {
    // Перенаправляем на главную страницу при успешном входе
    if (ModalRoute.of(context)?.settings.name == '/login') {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  void _handleSignedOut() {
    // Перенаправляем на страницу входа при выходе
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return widget.child;
  }
}
