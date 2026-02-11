import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable animated button with floating effect, scale animation, and haptic feedback.
///
/// Features:
/// - Hover: Scale up (1.05) + lift (-3px) + shadow elevation
/// - Tap: Scale down (0.95) + haptic feedback
/// - Smooth curves for premium feel
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool isLoading;
  final bool isDisabled;
  final BoxShadow? shadow;

  const AnimatedButton({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.width,
    this.height,
    this.borderRadius,
    this.isLoading = false,
    this.isDisabled = false,
    this.shadow,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _liftAnimation;

  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _liftAnimation = Tween<double>(
      begin: 0.0,
      end: -2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isDisabled && !widget.isLoading) {
      _controller.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isDisabled && !widget.isLoading) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (!widget.isDisabled && !widget.isLoading) {
      _controller.reverse();
    }
  }

  void _onHoverEnter(PointerEvent event) {
    if (!widget.isDisabled && !widget.isLoading) {
      setState(() => _isHovered = true);
    }
  }

  void _onHoverExit(PointerEvent event) {
    if (!widget.isDisabled && !widget.isLoading) {
      setState(() => _isHovered = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate hover effects
    final double hoverScale = _isHovered ? 1.05 : 1.0;
    final double hoverLift = _isHovered ? -3.0 : 0.0;
    final double shadowBlur = _isHovered ? 16.0 : 8.0;
    final double shadowOpacity = _isHovered ? 0.3 : 0.15;

    return MouseRegion(
      onEnter: _onHoverEnter,
      onExit: _onHoverExit,
      cursor: widget.isDisabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.isDisabled || widget.isLoading ? null : widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Combine hover and press animations
            final double combinedScale = hoverScale * _scaleAnimation.value;
            final double combinedLift = hoverLift + _liftAnimation.value;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translate(0.0, combinedLift)
                ..scale(combinedScale),
              transformAlignment: Alignment.center,
              child: AnimatedOpacity(
                opacity: widget.isDisabled ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius:
                        widget.borderRadius ?? BorderRadius.circular(16),
                    boxShadow: widget.shadow != null
                        ? [widget.shadow!]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: shadowOpacity,
                              ),
                              blurRadius: shadowBlur,
                              offset: Offset(0, 4 + (hoverLift.abs() / 2)),
                            ),
                          ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                        widget.borderRadius ?? BorderRadius.circular(16),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius:
                            widget.borderRadius ?? BorderRadius.circular(16),
                        onTap: widget.isDisabled || widget.isLoading
                            ? null
                            : widget.onTap,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: widget.isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              : widget.child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Lightweight floating button wrapper for simple use cases.
/// Use this for toolbar buttons, icon buttons, etc.
class FloatingIconButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const FloatingIconButton({
    super.key,
    required this.child,
    this.onTap,
    this.size = 40,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  State<FloatingIconButton> createState() => _FloatingIconButtonState();
}

class _FloatingIconButtonState extends State<FloatingIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
    HapticFeedback.selectionClick();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final double hoverScale = _isHovered ? 1.08 : 1.0;
    final double hoverLift = _isHovered ? -2.0 : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double combinedScale = hoverScale * _scaleAnimation.value;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translate(0.0, hoverLift)
                ..scale(combinedScale),
              transformAlignment: Alignment.center,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? const Color(0xFF2C2C2E),
                borderRadius:
                    widget.borderRadius ??
                    BorderRadius.circular(widget.size / 2),
              ),
              alignment: Alignment.center,
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}
