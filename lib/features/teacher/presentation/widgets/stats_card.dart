import 'package:flutter/material.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color cardColor;
  final Color textColor;
  final Color iconColor;
  final Color labelColor;
  final Color moreInfoColor;
  final String moreInfoText;
  final VoidCallback onTap;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.cardColor,
    required this.textColor,
    required this.iconColor,
    required this.labelColor,
    required this.moreInfoColor,
    required this.moreInfoText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Removed fixed height to allow dynamic sizing
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 8), // Reduced padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child:
                    Icon(icon, color: iconColor, size: 22), // Reduced icon size
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12, // Reduced title font size
                  ),
                ),
              ),
            ],
          ),
          // Value and moreInfoText aligned to bottom left
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: textColor,
                  fontSize: 22, // Reduced value font size
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                moreInfoText,
                style: TextStyle(
                  color: moreInfoColor, // Use the provided color
                  fontSize: 12, // Reduced moreInfoText font size
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
