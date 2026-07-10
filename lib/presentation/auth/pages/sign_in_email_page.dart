import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../notes/pages/notes_page.dart';
import '../bloc/auth_bloc.dart';
import '../../sync/bloc/sync_bloc.dart';

class SignInEmailPage extends StatefulWidget {
  const SignInEmailPage({super.key});

  @override
  State<SignInEmailPage> createState() => _SignInEmailPageState();
}

class _SignInEmailPageState extends State<SignInEmailPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isRegisterMode = false;
  String? _validationError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _validationError = 'Please enter a valid email');
      return;
    }
    if (password.length < 6) {
      setState(
        () => _validationError = 'Password must be at least 6 characters',
      );
      return;
    }
    setState(() => _validationError = null);

    final authBloc = context.read<AuthBloc>();
    if (_isRegisterMode) {
      authBloc.add(AuthRegisterRequested(email, password));
    } else {
      authBloc.add(AuthLoginRequested(email, password));
    }
  }

  void _onAuthStateChanged(BuildContext context, AuthState state) {
    if (state is! AuthAuthenticated) return;

    // Fire-and-forget so it doesn't block navigation.
    context.read<SyncBloc>().add(const SyncRequested());

    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(builder: (context) => const NotesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: _onAuthStateChanged,
      builder: (context, authState) {
        final isLoading = authState is AuthLoading;
        final errorMessage =
            _validationError ??
            (authState is AuthFailure
                ? authState.message.replaceAll('Exception: ', '')
                : null);

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Icon
                  Image.asset(
                    'assets/images/icon_email.png',
                    width: 100,
                    height: 100,
                  ),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    _isRegisterMode ? 'Create Account' : 'Sign In',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Error message
                  if (errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Text(
                        errorMessage,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.red[300],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Input Field
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textAlign: TextAlign.left,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'example@email.com',
                        hintStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Password Input Field
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      textAlign: TextAlign.left,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          onPressed: () {
                            setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Continue Button
                  _FloatingButton(
                    onTap: isLoading ? () {} : _handleSubmit,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isDark
                            ? const Color(0xFF2C2C2E)
                            : Colors.black, // Button color
                      ),
                      child: Center(
                        child: isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : Text(
                                _isRegisterMode ? 'Create Account' : 'Sign In',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Toggle between login and register
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isRegisterMode = !_isRegisterMode;
                        _validationError = null;
                      });
                    },
                    child: Text(
                      _isRegisterMode
                          ? 'Already have an account? Sign In'
                          : "Don't have an account? Create one",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        );
      },
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
