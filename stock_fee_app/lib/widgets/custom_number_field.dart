import 'package:flutter/material.dart';

class CustomNumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? suffixText;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const CustomNumberField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.suffixText,
    this.prefixIcon,
    this.onChanged,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF192237),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              if (prefixIcon != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(prefixIcon, size: 18, color: Colors.white54),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    suffixText: suffixText,
                    suffixStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: onChanged,
                ),
              ),
              if (onDecrement != null || onIncrement != null) ...[
                Container(
                  height: 32,
                  width: 1,
                  color: const Color(0xFF334155),
                ),
                if (onDecrement != null)
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18, color: Colors.white70),
                    onPressed: onDecrement,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    splashRadius: 18,
                  ),
                if (onIncrement != null)
                  IconButton(
                    icon: const Icon(Icons.add, size: 18, color: Colors.white70),
                    onPressed: onIncrement,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    splashRadius: 18,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
