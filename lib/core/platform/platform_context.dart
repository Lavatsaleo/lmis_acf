/// Country / implementation / module context returned by the backend.
///
/// The parser is deliberately tolerant: if an older backend does not yet send
/// platformContext, [isConfigured] is false and callers can preserve the
/// legacy role-based behaviour during a staged rollout.
class PlatformContext {
  final bool isConfigured;
  final String countryId;
  final String countryCode;
  final String countryName;
  final String implementationId;
  final String implementationCode;
  final String implementationName;
  final Set<String> enabledModules;

  const PlatformContext({
    required this.isConfigured,
    required this.countryId,
    required this.countryCode,
    required this.countryName,
    required this.implementationId,
    required this.implementationCode,
    required this.implementationName,
    required this.enabledModules,
  });

  factory PlatformContext.fromUserJson(Map<String, dynamic>? user) {
    final rawContext = user?['platformContext'];
    if (rawContext is! Map) return PlatformContext.legacy();

    final context = rawContext.cast<dynamic, dynamic>();
    final rawCountry = context['country'];
    final rawImplementation = context['implementation'];

    final country = rawCountry is Map ? rawCountry.cast<dynamic, dynamic>() : const <dynamic, dynamic>{};
    final implementation = rawImplementation is Map
        ? rawImplementation.cast<dynamic, dynamic>()
        : const <dynamic, dynamic>{};

    String value(Map<dynamic, dynamic> map, String key) =>
        (map[key] ?? '').toString().trim();

    final implementationId = value(implementation, 'id');
    final rawModules = context['enabledModules'];
    final modules = <String>{};
    if (rawModules is List) {
      for (final item in rawModules) {
        final module = item?.toString().trim().toUpperCase() ?? '';
        if (module.isNotEmpty) modules.add(module);
      }
    }

    return PlatformContext(
      isConfigured: implementationId.isNotEmpty,
      countryId: value(country, 'id'),
      countryCode: value(country, 'code'),
      countryName: value(country, 'name'),
      implementationId: implementationId,
      implementationCode: value(implementation, 'code'),
      implementationName: value(implementation, 'name'),
      enabledModules: modules,
    );
  }

  factory PlatformContext.legacy() => const PlatformContext(
        isConfigured: false,
        countryId: '',
        countryCode: '',
        countryName: '',
        implementationId: '',
        implementationCode: '',
        implementationName: '',
        enabledModules: <String>{},
      );

  bool isModuleEnabled(String moduleCode) {
    // Preserve old-app behaviour until the backend has been migrated and is
    // returning an implementation context.
    if (!isConfigured) return true;
    return enabledModules.contains(moduleCode.trim().toUpperCase());
  }

  String get displayName {
    if (countryName.isNotEmpty && implementationName.isNotEmpty) {
      return '$countryName • $implementationName';
    }
    if (implementationName.isNotEmpty) return implementationName;
    return countryName;
  }
}
