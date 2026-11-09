import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manga_sonic/services/theme_service.dart';
import 'package:manga_sonic/data/db/settings_db.dart';

class AeroBall extends StatefulWidget {
  final Function(int) onTabChanged;
  final int currentIndex;

  const AeroBall({
    super.key,
    required this.onTabChanged,
    required this.currentIndex,
  });

  @override
  State<AeroBall> createState() => _AeroBallState();
}

class _AeroBallState extends State<AeroBall> with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 500); // Initial position
  bool _isExpanded = false;
  bool _isDragging = false;
  double _opacity = 0.8;
  Timer? _dimTimer;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    // Load saved position
    final savedX = SettingsDB.getAeroBallX();
    final savedY = SettingsDB.getAeroBallY();
    if (savedX != null && savedY != null) {
      _position = Offset(savedX, savedY);
    }

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.elasticOut,
    );
    _startDimTimer();
  }

  @override
  void dispose() {
    _dimTimer?.cancel();
    _expandController.dispose();
    super.dispose();
  }

  void _startDimTimer() {
    _dimTimer?.cancel();
    _dimTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isExpanded && !_isDragging) {
        setState(() => _opacity = 0.4); // Subtle but clearly visible
      }
    });
  }

  void _resetOpacity() {
    setState(() {
      _opacity = 0.8;
      _startDimTimer();
    });
  }

  void _toggleExpanded() {
    _resetOpacity();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final accentColor = themeService.primaryColor;
    final size = MediaQuery.sizeOf(context);

    // Configuration
    const double padding = 20.0;
    const double orbSize = 50.0;
    const double thresholdX = 0.25; 
    const double menuSpacing = 25.0; // Increased spacing to prevent overlap

    // Calculate state
    final bool isVertical = _position.dx < size.width * thresholdX || 
                          _position.dx > size.width * (1 - thresholdX);
    
    // Cartesian Mapping: Determine Quadrants
    final bool isTopHalf = _position.dy < size.height / 2;
    final bool isLeftHalf = _position.dx < size.width / 2;

    // Dimensions
    final double menuWidth = isVertical ? 90 : 250; 
    final double menuHeight = isVertical ? 260 : 70;
    
    // 1. Vertical Logic: Pop DOWN if in top half, UP if in bottom half
    double menuTop;
    if (isTopHalf) {
      // Pop Down
      menuTop = _position.dy + orbSize + menuSpacing;
    } else {
      // Pop Up
      menuTop = _position.dy - menuHeight - menuSpacing;
    }
    
    // 2. Horizontal Logic: Center on ball then clamp to screen
    double menuLeft = _position.dx + (orbSize / 2) - (menuWidth / 2);
    menuLeft = menuLeft.clamp(padding, size.width - menuWidth - padding);

    return Stack(
      children: [
        // Background dimming
        if (_isExpanded)
          GestureDetector(
            onTap: _toggleExpanded,
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

        // 1. The Menu (Rendered BELOW the ball in the stack but positioned separately)
        if (_isExpanded || !_expandAnimation.isDismissed)
          Positioned(
            left: menuLeft,
            top: menuTop,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: ScaleTransition(
                scale: _expandAnimation,
                alignment: isTopHalf ? Alignment.topCenter : Alignment.bottomCenter,
                child: _buildMenu(accentColor, isVertical),
              ),
            ),
          ),
        
        // 2. The Draggable Orb (Keep on top for interaction)
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: Draggable(
            // DISABLE dragging when expanded
            maxSimultaneousDrags: _isExpanded ? 0 : 1,
            feedback: _buildOrb(accentColor, 1.0, true),
            onDragStarted: () {
              setState(() {
                _isDragging = true;
                _opacity = 0.8;
                _isExpanded = false;
                _expandController.reverse();
              });
              _dimTimer?.cancel();
            },
            onDragEnd: (details) {
              setState(() {
                _isDragging = false;
                
                // Keep exactly where dropped, but clamp to safe viewport
                double x = details.offset.dx;
                double y = details.offset.dy;
                
                x = x.clamp(padding, size.width - orbSize - padding);
                y = y.clamp(padding + 50, size.height - orbSize - padding - 10);
                
                _position = Offset(x, y);
                SettingsDB.saveAeroBallPosition(x, y);
              });
              _startDimTimer();
            },
            childWhenDragging: const SizedBox.shrink(),
            child: GestureDetector(
              onTap: _toggleExpanded,
              child: _buildOrb(accentColor, _opacity, false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrb(Color color, double opacity, bool isFeedback) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: opacity,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.3),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Icon(
              _isExpanded ? Icons.close : Icons.blur_on,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(Color color, bool isVertical) {
    final children = [
      _buildMenuItem(Icons.explore_outlined, 'Browse', 0, color, isVertical),
      SizedBox(width: isVertical ? 0 : 20, height: isVertical ? 15 : 0),
      _buildMenuItem(Icons.collections_bookmark_outlined, 'Library', 1, color, isVertical),
      SizedBox(width: isVertical ? 0 : 20, height: isVertical ? 15 : 0),
      _buildMenuItem(Icons.download_for_offline_outlined, 'Downs', 2, color, isVertical),
      SizedBox(width: isVertical ? 0 : 20, height: isVertical ? 15 : 0),
      _buildMenuItem(Icons.settings_outlined, 'Settings', 3, color, isVertical),
      if (isVertical) ...[
        const Divider(color: Colors.white24, height: 20),
        Text(
          'CH 5 • PG 12',
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ]
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, isVertical ? 28 : 20),
            child: isVertical 
                ? Column(mainAxisSize: MainAxisSize.min, children: children)
                : Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, int index, Color color, bool isVertical) {
    final isSelected = widget.currentIndex == index;
    return GestureDetector(
      onTap: () {
        widget.onTabChanged(index);
        _toggleExpanded();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? color : Colors.white70,
            size: isVertical ? 24 : 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.white70,
              fontSize: isVertical ? 9 : 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
