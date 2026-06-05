part of 'control_page.dart';

class _HomeTopSection extends StatelessWidget {
  final ble.ConnectionState connState;

  const _HomeTopSection({required this.connState});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: ReplicaColors.pageBg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(connState: connState),
          _StatusSection(connState: connState),
          const SizedBox(height: 16),
          _HomeStatusLine(connState: connState),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
