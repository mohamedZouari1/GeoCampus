import 'package:flutter/material.dart';

class BottomNavWidget extends StatelessWidget {
  const BottomNavWidget(
      {super.key, required this.onTapTab, required this.currentActiveIndex});
  final Function(int) onTapTab;
  final int currentActiveIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF020617), // Matches standard dark background
        border: Border(
          top: BorderSide(color: Colors.blueAccent.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.greenAccent,
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Text('🎮', style: TextStyle(fontSize: 22)),
              activeIcon: Text('🎮', style: TextStyle(fontSize: 26, shadows: [Shadow(color: Colors.greenAccent, blurRadius: 10)])),
              label: 'HUB',
            ),
            BottomNavigationBarItem(
              icon: Text('🗺️', style: TextStyle(fontSize: 22)),
              activeIcon: Text('🗺️', style: TextStyle(fontSize: 26, shadows: [Shadow(color: Colors.greenAccent, blurRadius: 10)])),
              label: 'MAP',
            ),
            BottomNavigationBarItem(
              icon: Text('🎯', style: TextStyle(fontSize: 22)),
              activeIcon: Text('🎯', style: TextStyle(fontSize: 26, shadows: [Shadow(color: Colors.greenAccent, blurRadius: 10)])),
              label: 'PLAY',
            ),
            BottomNavigationBarItem(
              icon: Text('🏆', style: TextStyle(fontSize: 22)),
              activeIcon: Text('🏆', style: TextStyle(fontSize: 26, shadows: [Shadow(color: Colors.greenAccent, blurRadius: 10)])),
              label: 'RANKS',
            ),
            BottomNavigationBarItem(
              icon: Text('⚙️', style: TextStyle(fontSize: 22)),
              activeIcon: Text('⚙️', style: TextStyle(fontSize: 26, shadows: [Shadow(color: Colors.greenAccent, blurRadius: 10)])),
              label: 'MORE',
            ),
          ],
          onTap: onTapTab,
          currentIndex: currentActiveIndex,
        ),
    );
  }
}
