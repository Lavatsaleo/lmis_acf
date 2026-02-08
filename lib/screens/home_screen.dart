import 'package:flutter/material.dart';
import '../commodity/multi_scan_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiScanPage(
      title: "Scan Boxes",
      expectedCount: 10,
      helperText: "Scan the QR codes on the boxes.",
    );
  }
}
