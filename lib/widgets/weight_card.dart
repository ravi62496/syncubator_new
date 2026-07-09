import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weight_provider.dart';
import '../utils/app_colors.dart';
import 'loading_widget.dart';

/// Displays the baby's current body weight, refreshed live from the
/// Raspberry Pi via [WeightProvider]. Handles four states:
/// loading (first fetch), connected (fresh reading), offline
/// (device unreachable), and error (unexpected response).
class WeightCard extends StatefulWidget {
  const WeightCard({super.key});

  @override
  State<WeightCard> createState() => _WeightCardState();
}

class _WeightCardState extends State<WeightCard> {
  @override
  void initState() {
    super.initState();
    // Start polling once this card is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeightProvider>().startMonitoring();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WeightProvider>(
      builder: (context, weightProvider, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.monitor_weight_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current Body Weight',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  _StatusDot(status: weightProvider.status),
                ],
              ),
              const SizedBox(height: 16),
              _buildBody(weightProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(WeightProvider provider) {
    switch (provider.status) {
      case WeightConnectionStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LoadingWidget(),
        );

      case WeightConnectionStatus.connected:
        final weight = provider.currentWeight;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              weight?.value.toStringAsFixed(2) ?? '--',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              weight?.unit ?? 'kg',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

      case WeightConnectionStatus.offline:
        return _MessageRow(
          icon: Icons.wifi_off_rounded,
          color: AppColors.offline,
          message: 'Device offline. Check Raspberry Pi connection.',
        );

      case WeightConnectionStatus.error:
        return _MessageRow(
          icon: Icons.error_outline_rounded,
          color: AppColors.error,
          message: provider.lastErrorMessage ?? 'Something went wrong.',
        );
    }
  }
}

class _StatusDot extends StatelessWidget {
  final WeightConnectionStatus status;

  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case WeightConnectionStatus.connected:
        color = AppColors.success;
        break;
      case WeightConnectionStatus.loading:
        color = AppColors.primary;
        break;
      case WeightConnectionStatus.offline:
        color = AppColors.offline;
        break;
      case WeightConnectionStatus.error:
        color = AppColors.error;
        break;
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _MessageRow({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: color, fontSize: 13),
          ),
        ),
      ],
    );
  }
}