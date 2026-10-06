import 'package:flutter/material.dart';

import '../../services/company_settings_service.dart';

/// Displays the administrator-managed logo wherever the application is branded.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, this.size = 38, this.fallbackColor});

  final double size;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final color = fallbackColor ?? Theme.of(context).colorScheme.onPrimary;
    return SizedBox.square(
      dimension: size,
      child: StreamBuilder(
        stream: CompanySettingsService.instance.watchSettings(),
        builder: (context, snapshot) {
          final url = snapshot.data?.logoUrl?.trim();
          if (url == null || url.isEmpty) {
            return Icon(
              Icons.local_parking_rounded,
              color: color,
              size: size * 0.68,
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.local_parking_rounded,
                color: color,
                size: size * 0.68,
              ),
            ),
          );
        },
      ),
    );
  }
}
