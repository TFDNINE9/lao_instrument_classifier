import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/classifier_provider.dart';
import 'ui/screens/home_screen.dart';
import 'utils/constants.dart';

class LaoInstrumentClassifierApp extends StatelessWidget {
  const LaoInstrumentClassifierApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ClassifierProvider(),
      child: MaterialApp(
        title: AppConstants.appName,
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
