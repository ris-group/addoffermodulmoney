
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'addofferpage.dart';
import 'loginpage.dart';
import 'offerslistpage.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://brbiymcyjllabpnwdpfp.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJyYml5bWN5amxsYWJwbndkcGZwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMwMTExMjksImV4cCI6MjA2ODU4NzEyOX0.llEzm9mmPytuioLVMhWstd5O_0duWJXn_fn3yY_kAZo',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Финансовые предложения',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routes: {
        '/login': (_) => LoginPage(),
        '/': (_) => const HomePage(),
        '/add_offer': (_) => const AddOfferPage(),
        '/offers_list': (_) => OffersListPage(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    if (supabase.auth.currentUser == null) {
      // Если не залогинен — переходим на логин (после первого кадра)
      WidgetsBinding.instance.addPostFrameCallback(
            (_) => Navigator.pushReplacementNamed(context, '/login'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Финансовые предложения'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/add_offer'),
              child: const Text('Добавить оффер'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/offers_list'),
              child: const Text('Просмотреть список офферов'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Пример массового добавления "займа".
  /// Для карточек используй `product_info` / `borrower_requirements`,
  /// а `term`/`age` здесь оставлены пустыми, чтобы не путаться.
  Future<void> _addOffer({required String logo, required String brand}) async {
    final supabase = Supabase.instance.client;
    await supabase.from('offerfromapi').insert({
      'sort_order': 0,
      'category': 'loan',          // для карт будет 'credit_card' / 'debit_card'
      'logo': logo,
      'brand': brand,
      'label': '',
      'amount_up': 0,

      // старые текстовые
      'term': '',
      'age': '',

      // новые текстовые поля под карточки
      'product_info': '',
      'borrower_requirements': '',

      'button_link': '',
      'advertisement': '',
      'path': '',
    });
  }
}
