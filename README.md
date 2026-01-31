# lmis_acf

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

**APP structure**

- lib/main.dart → app entry point
- lib/lmis_app.dart → MaterialApp + theme + home
- lib/core/ → colors + theme
- lib/screens/home_screen.dart → clean home page (module cards)
- lib/screens/commodity/ → each feature is its own page:
- commodity_management_page.dart
- register_box_page.dart
- bulk_register_boxes_page.dart
- dispatch_page.dart
- receive_page.dart
- multi_scan_page.dart
- shipments_page.dart
- box_details_page.dart
- lib/models/ → Facility / Box / Shipment / Results models
- lib/stores/ → SharedPreferences stores (BoxStore, ShipmentStore)