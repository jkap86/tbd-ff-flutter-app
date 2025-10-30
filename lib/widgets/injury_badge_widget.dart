import 'package:flutter/material.dart';
import '../models/player_model.dart';

class InjuryBadgeWidget extends StatelessWidget {
  final Player player;
  final double size;

  const InjuryBadgeWidget({
    super.key,
    required this.player,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (!player.isInjured) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: _getTooltipMessage(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: size * 0.3,
          vertical: size * 0.15,
        ),
        decoration: BoxDecoration(
          color: player.injuryStatusColor,
          borderRadius: BorderRadius.circular(size * 0.2),
        ),
        child: Text(
          _getAbbreviation(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getAbbreviation() {
    switch (player.injuryStatus) {
      case 'Out':
        return 'O';
      case 'Doubtful':
        return 'D';
      case 'Questionable':
        return 'Q';
      case 'IR':
        return 'IR';
      case 'PUP':
        return 'PUP';
      default:
        return '';
    }
  }

  String _getTooltipMessage() {
    final designation = player.injuryDesignation ?? 'Injury';
    final status = player.injuryStatus ?? '';

    if (player.injuryReturnDate != null) {
      final returnDate = player.injuryReturnDate!;
      return '$designation - $status (Est. return: ${returnDate.month}/${returnDate.day})';
    }

    return '$designation - $status';
  }
}
