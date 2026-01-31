import 'package:flutter/material.dart';
import 'package:lmis_acf/core/colors.dart';
import 'package:lmis_acf/screens/commodity/commodity_management_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LMIS ACF"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _HomeCard(
              title: "Commodity Management",
              subtitle: "Register boxes, print QR, dispatch and receive",
              icon: Icons.inventory_2_outlined,
              color: acfBlue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CommodityManagementPage()),
                );
              },
            ),
            const SizedBox(height: 12),
            _HomeCard(
              title: "Clinical Data",
              subtitle: "Coming next (module will be added after Logistics)",
              icon: Icons.medical_services_outlined,
              color: acfGreen,
              onTap: null,
              disabled: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool disabled;

  const _HomeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: disabled ? null : onTap,
        ),
      ),
    );
  }
}
