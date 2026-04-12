import 'dart:ui';
import 'package:flutter/material.dart';

class OculisSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const OculisSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<OculisSidebar> createState() => _OculisSidebarState();
}

class _OculisSidebarState extends State<OculisSidebar> {
  bool _isExpanded = true;

  // Paleta de colores
  static const Color oculisBg = Color(0xFF0A0B0F);
  static const Color oculisAccentPurple = Color(0xFF6366F1);
  static const Color oculisAccentBlue = Color(0xFF3B82F6);

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'index': 0},
    {'icon': Icons.account_tree_outlined, 'label': 'Automation', 'index': 1},
    {'icon': Icons.shield_outlined, 'label': 'Security', 'index': 2},
    {'icon': Icons.business_outlined, 'label': 'Fleet', 'index': 3},
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      width: _isExpanded ? 240 : 72,
      decoration: BoxDecoration(
        color: oculisBg.withOpacity(0.9),
        border: const Border(
          right: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: _menuItems.map((item) {
                    return _buildMenuItem(
                      item['icon'],
                      item['label'],
                      item['index'],
                    );
                  }).toList(),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [oculisAccentPurple, oculisAccentBlue],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            if (_isExpanded) ...[
              const SizedBox(width: 12),
              Text(
                "PortalPilot",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'sans-serif',
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, int index) {
    final bool isSelected = widget.selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: StatefulBuilder(
          builder: (context, setStateItem) {
            bool isHovered = false;
            return MouseRegion(
              onEnter: (_) => setStateItem(() => isHovered = true),
              onExit: (_) => setStateItem(() => isHovered = false),
              child: GestureDetector(
                onTap: () => widget.onItemSelected(index),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? oculisAccentPurple.withOpacity(0.2)
                            : (isHovered
                                ? Colors.white.withOpacity(0.05)
                                : Colors.transparent),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: oculisAccentPurple.withOpacity(0.3))
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: _isExpanded
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding:
                                EdgeInsets.only(left: _isExpanded ? 12 : 0),
                            child: Icon(
                              icon,
                              color: (isSelected || isHovered)
                                  ? oculisAccentPurple
                                  : Colors.white38,
                              size: 22,
                            ),
                          ),
                          if (_isExpanded) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Tooltip emergente (cuando sidebar contraída)
                    if (!_isExpanded && isHovered && !isSelected)
                      Positioned(
                        left: 60,
                        top: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: oculisAccentPurple.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: oculisAccentPurple.withOpacity(0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'sans-serif',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  oculisAccentPurple.withOpacity(0.2),
                  oculisAccentBlue.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: oculisAccentPurple.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: Colors.white, size: 18),
                if (_isExpanded) ...[
                  const SizedBox(width: 8),
                  const Text(
                    "New Post",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [oculisAccentPurple, oculisAccentBlue],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                ),
                if (_isExpanded) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Joseph",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                        Text(
                          "Developer",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontFamily: 'sans-serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
