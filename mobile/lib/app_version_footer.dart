import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'rhm_theme.dart';

class RhmAppVersionFooter extends StatefulWidget {
  const RhmAppVersionFooter({super.key});

  @override
  State<RhmAppVersionFooter> createState() => _RhmAppVersionFooterState();
}

class _RhmAppVersionFooterState extends State<RhmAppVersionFooter> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).extension<RhmUiTokens>()!.border,
              ),
            ),
          ),
          child: FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = info == null
                  ? 'الإصدار …'
                  : 'الإصدار ${info.version}+${info.buildNumber}';
              return Text(
                'RHM  •  $version  •  © ${DateTime.now().year}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: .2,
                ),
              );
            },
          ),
        ),
      );
}
