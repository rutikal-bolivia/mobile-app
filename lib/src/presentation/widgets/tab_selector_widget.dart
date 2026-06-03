import 'package:flutter/material.dart';

class TabSelectorWidget extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const TabSelectorWidget({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: tabs.asMap().entries.map((entry) {
        final i = entry.key;
        final label = entry.value;
        final isSelected = i == selectedIndex;

        return GestureDetector(
          onTap: () => onTabSelected(i),
          child: Container(
            margin: EdgeInsets.only(right: i < tabs.length - 1 ? 16 : 0),
            padding: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isSelected
                      ? const Color(0xFFF4C025)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? const Color(0xFF3D2B1F)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
