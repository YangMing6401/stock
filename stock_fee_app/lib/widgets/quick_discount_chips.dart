import 'package:flutter/material.dart';

class QuickDiscountChips extends StatelessWidget {
  final double currentDiscount;
  final ValueChanged<double> onSelected;

  const QuickDiscountChips({
    super.key,
    required this.currentDiscount,
    required this.onSelected,
  });

  static const List<Map<String, double>> discountOptions = [
    {'6 折': 0.60},
    {'5 折': 0.50},
    {'3.8 折': 0.38},
    {'2.8 折': 0.28},
    {'2 折': 0.20},
    {'1 折': 0.10},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: discountOptions.map((item) {
          final label = item.keys.first;
          final val = item.values.first;
          final isSelected = (currentDiscount - val).abs() < 0.005;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onSelected(val);
                }
              },
              selectedColor: const Color(0xFF3B82F6),
              backgroundColor: const Color(0xFF1E293B),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF334155),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
