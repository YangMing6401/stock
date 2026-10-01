import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/calculator_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkBg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const StockFeeApp());
}

class StockFeeApp extends StatelessWidget {
  const StockFeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '台股手續費計算器',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const CalculatorScreen(),
    );
  }
}
