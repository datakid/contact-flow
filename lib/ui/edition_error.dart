import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/edition.dart';

class EditionErrorApp extends StatelessWidget {
  final String native;
  final String lang;
  const EditionErrorApp({super.key, required this.native, required this.lang});

  @override
  Widget build(BuildContext context) {
    final l = L(lang);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Directionality(
                textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                child: Text(
                  l.t('editionMismatch', {
                    'native': native,
                    'dart': Edition.dartName(),
                  }),
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
