import 'package:ai_teacher/manager/user_manager.dart';
import 'package:ai_teacher/pages/main_page.dart';
import 'package:ai_teacher/util/sp_util.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SPUtil.initSharedPreferences();
  await initializeDateFormatting('zh_CN');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalLoaderOverlay(
      overlayWidgetBuilder: (progress) {
        return Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black87,
            ),
            child: Center(
              child: SizedBox(
                width: 45,
                height: 45,
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
        );
      },
      child: MaterialApp(
        title: 'AI Teacher',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF82A6F5)),
          useMaterial3: true,
        ),
        home: UserManager().isLogin() ? MainPage() : const LoginPage(),
      ),
    );
  }
}
