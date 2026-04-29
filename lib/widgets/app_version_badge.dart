import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Small reusable widget that shows the installed app version and build number.
///
/// Example output:
/// Version 1.0.2 Build 4
class AppVersionBadge extends StatefulWidget {
  final TextAlign textAlign;
  final bool showAppName;

  const AppVersionBadge({
    super.key,
    this.textAlign = TextAlign.center,
    this.showAppName = false,
  });

  @override
  State<AppVersionBadge> createState() => _AppVersionBadgeState();
}

class _AppVersionBadgeState extends State<AppVersionBadge> {
  String _versionText = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;

      final appName = widget.showAppName ? '${info.appName} • ' : '';
      setState(() {
        _versionText = '${appName}Version ${info.version} Build ${info.buildNumber}';
      });
    } catch (_) {
      // Version display should never block login or app usage.
      if (!mounted) return;
      setState(() => _versionText = 'Version unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_versionText.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Text(
      _versionText,
      textAlign: widget.textAlign,
      style: TextStyle(
        fontSize: 12,
        height: 1.2,
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
