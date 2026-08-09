import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/localization/app_strings.dart';
import '../../locale/bloc/locale_bloc.dart';
import 'sign_in_email_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Анимации
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _btn1Opacity;
  late Animation<Offset> _btn1Slide;
  late Animation<double> _guestOpacity;
  late Animation<Offset> _guestSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // --- Настройка анимаций (выезжают снизу) ---

    // 1. Текст
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
          ),
        );

    // 2. Кнопка Email
    _btn1Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );
    _btn1Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
          ),
        );

    // 3. Гостевой режим
    _guestOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.8, curve: Curves.easeOut),
      ),
    );
    _guestSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.55, 0.8, curve: Curves.easeOut),
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _controller.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final locale = context.watch<LocaleBloc>().state.locale;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            // minHeight + IntrinsicHeight, not a fixed-height SizedBox: the
            // box used to pin the column to exactly the screen height, which
            // made the surrounding SingleChildScrollView dead weight -- the
            // content could never scroll, it could only overflow. It now
            // fills the viewport when there is room (so `Spacer` still
            // absorbs the slack and the spacing below is unchanged) and
            // scrolls instead of overflowing when there isn't, e.g. a short
            // screen or a large system font scale.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Эта пружина сверху будет сжиматься, так как мы увеличили отступ ниже
                          const Spacer(),

                          // Анимированный Текст
                          FadeTransition(
                            opacity: _textOpacity,
                            child: SlideTransition(
                              position: _textSlide,
                              child: Column(
                                children: [
                                  Text(
                                    AppStrings.tr(locale, AppStrings.welcomeTo),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 32,
                                      height: 1.3,
                                      color: textColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    AppStrings.tr(locale, AppStrings.archset),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 42,
                                      height: 1.1,
                                      color: textColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // --- ИЗМЕНЕНИЕ ЗДЕСЬ ---
                          // Было height: 80. Увеличили до 18% высоты экрана.
                          // Это создаст большую "дырку" посередине, выталкивая текст вверх.
                          SizedBox(height: screenHeight * 0.18),

                          // Кнопка Email
                          FadeTransition(
                            opacity: _btn1Opacity,
                            child: SlideTransition(
                              position: _btn1Slide,
                              child: _buildButton(
                                context,
                                text: AppStrings.tr(
                                  locale,
                                  AppStrings.signInEmail,
                                ),
                                iconPath: 'assets/images/icon_email.png',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (context) =>
                                          const SignInEmailPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Гостевой режим -- вход без аккаунта
                          FadeTransition(
                            opacity: _guestOpacity,
                            child: SlideTransition(
                              position: _guestSlide,
                              child: GuestModeButton(
                                label: AppStrings.tr(
                                  locale,
                                  AppStrings.continueAsGuest,
                                ),
                              ),
                            ),
                          ),

                          // Нижний отступ оставляем как есть (или чуть уменьшаем, если кнопки улетели слишком низко)
                          SizedBox(height: screenHeight * 0.09),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String text,
    required String iconPath,
    required VoidCallback onPressed,
  }) {
    final double buttonWidth = MediaQuery.of(context).size.width * 0.85;
    final double effectiveWidth = buttonWidth > 502 ? 502 : buttonWidth;

    return _FloatingButton(
      onTap: onPressed,
      child: Container(
        width: effectiveWidth,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFff6d00), Color(0xFFf3a501)],
            stops: [0.2452, 1.0],
          ),
          borderRadius: BorderRadius.circular(61),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                iconPath,
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.circle, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                text,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.white, // Text inside button stays white
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating button wrapper with hover/tap animations
class _FloatingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _FloatingButton({required this.child, required this.onTap});

  @override
  State<_FloatingButton> createState() => _FloatingButtonState();
}

class _FloatingButtonState extends State<_FloatingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double hoverScale = _isHovered ? 1.03 : 1.0;
    final double hoverLift = _isHovered ? -2.0 : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double combinedScale = hoverScale * _scaleAnimation.value;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translate(0.0, hoverLift)
                ..scale(combinedScale),
              transformAlignment: Alignment.center,
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}
