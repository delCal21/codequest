import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codequest/features/auth/domain/models/user_model.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_event.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_state.dart';
import 'package:codequest/config/routes.dart';
import 'package:codequest/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:codequest/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _noAdmin = false;
  bool _mounted = true;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Add these for student role check
  bool _isStudentEmail = false;
  bool _checkingRole = false;
  String? _roleError;
  final FocusNode _emailFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkIfNoAdmin();
    _initializeAnimations();
    _emailFocusNode.addListener(_onEmailFocusChange);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _mounted = false;
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _onEmailFocusChange() {
    if (!_emailFocusNode.hasFocus) {
      _checkIfStudentEmail(_emailController.text.trim());
    }
  }

  Future<void> _checkIfStudentEmail(String email) async {
    if (email.isEmpty) {
      setState(() {
        _isStudentEmail = false;
        _roleError = null;
      });
      return;
    }
    setState(() {
      _checkingRole = true;
      _roleError = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final role = (data['role'] ?? '').toString().toLowerCase();
        setState(() {
          _isStudentEmail = role == 'student';
          _roleError = _isStudentEmail ? null : 'Please enter your password.';
        });
      } else {
        setState(() {
          _isStudentEmail = false;
          _roleError = 'No user found with this email.';
        });
      }
    } catch (e) {
      setState(() {
        _isStudentEmail = false;
        _roleError = 'Error checking user role.';
      });
    } finally {
      setState(() {
        _checkingRole = false;
      });
    }
  }

  Future<void> _checkIfNoAdmin() async {
    if (!_mounted) return;
    try {
      final adminSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();
      if (_mounted) {
        setState(() {
          _noAdmin = adminSnapshot.docs.isEmpty;
        });
      }
    } catch (e) {
      print('Error checking for admin: $e');
    }
  }

  void _handleLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            LoginRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }

  void _showSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Successfully logged in!'),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_noAdmin && kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRouter.firstAdminRegister);
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            _showSuccessSnackbar();
            if (state.user.role == UserRole.admin) {
              Navigator.pushReplacementNamed(context, '/admin-dashboard');
            } else if (state.user.role == UserRole.teacher) {
              Navigator.pushReplacementNamed(
                  context, AppRouter.teacherDashboard);
            } else if (state.user.role == UserRole.student) {
              Navigator.pushReplacementNamed(
                  context, AppRouter.studentDashboard);
            }
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: Colors.red[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green[50]!,
                  Colors.white,
                  Colors.green[100]!,
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48.0, vertical: 24.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 800;
                        return isWide
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Left side - Login form
                                  Expanded(
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 380),
                                        child: FadeTransition(
                                          opacity: _fadeAnimation,
                                          child: SlideTransition(
                                            position: _slideAnimation,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.1),
                                                    blurRadius: 15,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.blue
                                                        .withOpacity(0.05),
                                                    blurRadius: 30,
                                                    offset: const Offset(0, 15),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // Login Form Section
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              24),
                                                      child: Form(
                                                        key: _formKey,
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .stretch,
                                                          children: [
                                                            // Welcome Text
                                                            Column(
                                                              children: [
                                                                const Text(
                                                                  'Welcome Back',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        25,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .black87,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    height: 6),
                                                                Text(
                                                                  'Sign in to continue your learning journey',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    color: Colors
                                                                            .grey[
                                                                        600],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                                height: 24),

                                                            // Email Field
                                                            TextFormField(
                                                              controller:
                                                                  _emailController,
                                                              focusNode:
                                                                  _emailFocusNode,
                                                              keyboardType:
                                                                  TextInputType
                                                                      .emailAddress,
                                                              decoration:
                                                                  InputDecoration(
                                                                labelText:
                                                                    'Email Address',
                                                                hintText:
                                                                    'Enter your email address',
                                                                prefixIcon: const Icon(
                                                                    Icons
                                                                        .email_outlined,
                                                                    color: Colors
                                                                        .grey),
                                                                enabledBorder:
                                                                    UnderlineInputBorder(
                                                                  borderSide:
                                                                      BorderSide(
                                                                    color: (state
                                                                            is AuthError)
                                                                        ? Theme.of(context)
                                                                            .colorScheme
                                                                            .error
                                                                        : Colors
                                                                            .grey
                                                                            .shade400,
                                                                  ),
                                                                ),
                                                                focusedBorder:
                                                                    UnderlineInputBorder(
                                                                  borderSide:
                                                                      BorderSide(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .primary,
                                                                    width: 2,
                                                                  ),
                                                                ),
                                                                errorBorder:
                                                                    UnderlineInputBorder(
                                                                  borderSide: BorderSide(
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .error),
                                                                ),
                                                                focusedErrorBorder:
                                                                    UnderlineInputBorder(
                                                                  borderSide:
                                                                      BorderSide(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .error,
                                                                    width: 2,
                                                                  ),
                                                                ),
                                                                filled: true,
                                                                fillColor: Colors
                                                                    .transparent,
                                                                contentPadding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                        vertical:
                                                                            8.0,
                                                                        horizontal:
                                                                            0.0),
                                                                floatingLabelBehavior:
                                                                    FloatingLabelBehavior
                                                                        .auto,
                                                              ),
                                                              validator:
                                                                  (value) {
                                                                if (value ==
                                                                        null ||
                                                                    value
                                                                        .isEmpty) {
                                                                  return 'Please enter your email';
                                                                }
                                                                if (!RegExp(
                                                                        r'^[^@]+@[^@]+\.[^@]+')
                                                                    .hasMatch(
                                                                        value)) {
                                                                  return 'Please enter a valid email address';
                                                                }
                                                                return null;
                                                              },
                                                              onChanged:
                                                                  (value) {
                                                                // Optionally, check role on every change
                                                                // _checkIfStudentEmail(value.trim());
                                                              },
                                                            ),
                                                            const SizedBox(
                                                                height: 20),

                                                            // Password Field
                                                            AuthTextField(
                                                              controller:
                                                                  _passwordController,
                                                              labelText:
                                                                  'Password',
                                                              hintText:
                                                                  'Enter your password',
                                                              obscureText:
                                                                  !_isPasswordVisible,
                                                              prefixIcon: Icons
                                                                  .lock_outlined,
                                                              suffixIcon:
                                                                  IconButton(
                                                                icon: Icon(
                                                                  _isPasswordVisible
                                                                      ? Icons
                                                                          .visibility
                                                                      : Icons
                                                                          .visibility_off,
                                                                  color: Colors
                                                                          .grey[
                                                                      600],
                                                                ),
                                                                onPressed: () {
                                                                  setState(() {
                                                                    _isPasswordVisible =
                                                                        !_isPasswordVisible;
                                                                  });
                                                                },
                                                              ),
                                                              validator:
                                                                  (value) {
                                                                if (value ==
                                                                        null ||
                                                                    value
                                                                        .isEmpty) {
                                                                  return 'Please enter your password';
                                                                }
                                                                if (value
                                                                        .length <
                                                                    8) {
                                                                  return 'Password must be at least 8 characters';
                                                                }
                                                                return null;
                                                              },
                                                              hasError: state
                                                                  is AuthError,
                                                              showUnderline:
                                                                  true,
                                                            ),
                                                            const SizedBox(
                                                                height: 20),

                                                            // Login Button
                                                            Container(
                                                              height: 48,
                                                              decoration:
                                                                  BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                                gradient:
                                                                    LinearGradient(
                                                                  colors: [
                                                                    Colors.green[
                                                                        600]!,
                                                                    Colors.green[
                                                                        700]!,
                                                                  ],
                                                                ),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .green
                                                                        .withOpacity(
                                                                            0.3),
                                                                    blurRadius:
                                                                        8,
                                                                    offset:
                                                                        const Offset(
                                                                            0,
                                                                            4),
                                                                  ),
                                                                ],
                                                              ),
                                                              child:
                                                                  ElevatedButton(
                                                                onPressed: isLoading
                                                                    ? null
                                                                    : _handleLogin,
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .transparent,
                                                                  shadowColor:
                                                                      Colors
                                                                          .transparent,
                                                                  shape:
                                                                      RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12),
                                                                  ),
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          12),
                                                                ),
                                                                child: isLoading
                                                                    ? const SizedBox(
                                                                        height:
                                                                            20,
                                                                        width:
                                                                            20,
                                                                        child:
                                                                            CircularProgressIndicator(
                                                                          strokeWidth:
                                                                              2,
                                                                          valueColor:
                                                                              AlwaysStoppedAnimation<Color>(Colors.white),
                                                                        ),
                                                                      )
                                                                    : const Text(
                                                                        'LOGIN',
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 16),
                                                            // Face Login Button
                                                            if (_checkingRole)
                                                              const Padding(
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        vertical:
                                                                            8.0),
                                                                child: Center(
                                                                    child:
                                                                        CircularProgressIndicator()),
                                                              ),
                                                            if (_roleError !=
                                                                null)
                                                              Padding(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        8.0),
                                                                child: Text(
                                                                  _roleError!,
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .red,
                                                                      fontSize:
                                                                          14),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                ),
                                                              ),
                                                            const SizedBox(
                                                                height: 12),

                                                            // Forgot Password Link
                                                            Center(
                                                              child: TextButton(
                                                                onPressed: () {
                                                                  Navigator
                                                                      .push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder:
                                                                          (context) =>
                                                                              const ForgotPasswordPage(),
                                                                    ),
                                                                  );
                                                                },
                                                                style: TextButton
                                                                    .styleFrom(
                                                                  foregroundColor:
                                                                      Colors.green[
                                                                          600],
                                                                  textStyle:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                                child: const Text(
                                                                    'Forgot Password?'),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 12),

                                                            // Divider
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child:
                                                                      Divider(
                                                                    color: Colors
                                                                            .grey[
                                                                        300],
                                                                    thickness:
                                                                        1,
                                                                  ),
                                                                ),
                                                                Padding(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12),
                                                                  child: Text(
                                                                    '',
                                                                    style:
                                                                        TextStyle(
                                                                      color: Colors
                                                                              .grey[
                                                                          600],
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  child:
                                                                      Divider(
                                                                    color: Colors
                                                                            .grey[
                                                                        300],
                                                                    thickness:
                                                                        1,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                                height: 12),

                                                            // Register Link
                                                            Center(
                                                              child: TextButton(
                                                                onPressed: () {
                                                                  Navigator.pushReplacementNamed(
                                                                      context,
                                                                      AppRouter
                                                                          .register);
                                                                },
                                                                style: TextButton
                                                                    .styleFrom(
                                                                  foregroundColor:
                                                                      Colors.green[
                                                                          600],
                                                                  textStyle:
                                                                      const TextStyle(
                                                                          fontSize:
                                                                              14),
                                                                ),
                                                                child: RichText(
                                                                  text:
                                                                      TextSpan(
                                                                    style: TextStyle(
                                                                        color: Colors.green[
                                                                            600],
                                                                        fontSize:
                                                                            14),
                                                                    children: [
                                                                      const TextSpan(
                                                                          text:
                                                                              ""),
                                                                      TextSpan(
                                                                        text:
                                                                            '',
                                                                        style: TextStyle(
                                                                            color:
                                                                                Colors.green[600],
                                                                            fontWeight: FontWeight.bold),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 40),
                                  // Right side - Logo and branding
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/images/CIS SEAL2.png',
                                          width: 400,
                                          height: 400,
                                          fit: BoxFit.cover,
                                        ),
                                        SizedBox(height: 20),
                                        RichText(
                                          text: TextSpan(
                                            style: TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.0,
                                              fontFamily: 'Poppins',
                                            ),
                                            children: [
                                              TextSpan(
                                                text: 'Code',
                                                style: TextStyle(
                                                    color: Colors.black),
                                              ),
                                              TextSpan(
                                                text: ' Quest',
                                                style: TextStyle(
                                                    color: Colors.black),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'Craft Your Code, Shape Your Future',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(height: 32),
                                  Center(
                                    child: Image.asset(
                                      'assets/images/CIS SEAL2.png',
                                      width: 150,
                                      height: 150,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                        fontFamily: 'Poppins',
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'Code',
                                          style: TextStyle(color: Colors.black),
                                        ),
                                        TextSpan(
                                          text: ' Quest',
                                          style: TextStyle(color: Colors.black),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Craft Your Code, Shape Your Future',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 32),
                                  // The login card
                                  Center(
                                    child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 280),
                                      child: FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position: _slideAnimation,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 15,
                                                  offset: const Offset(0, 8),
                                                ),
                                                BoxShadow(
                                                  color: Colors.blue
                                                      .withOpacity(0.05),
                                                  blurRadius: 30,
                                                  offset: const Offset(0, 15),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Login Form Section
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            24),
                                                    child: Form(
                                                      key: _formKey,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          // Welcome Text
                                                          Column(
                                                            children: [
                                                              const Text(
                                                                'Welcome Back',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 22,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 6),
                                                              Text(
                                                                'Sign in to continue your learning journey',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 14,
                                                                  color: Colors
                                                                          .grey[
                                                                      600],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 24),

                                                          // Email Field
                                                          TextFormField(
                                                            controller:
                                                                _emailController,
                                                            focusNode:
                                                                _emailFocusNode,
                                                            keyboardType:
                                                                TextInputType
                                                                    .emailAddress,
                                                            decoration:
                                                                InputDecoration(
                                                              labelText:
                                                                  'Email Address',
                                                              hintText:
                                                                  'Enter your email address',
                                                              prefixIcon: const Icon(
                                                                  Icons
                                                                      .email_outlined,
                                                                  color: Colors
                                                                      .grey),
                                                              enabledBorder:
                                                                  UnderlineInputBorder(
                                                                borderSide:
                                                                    BorderSide(
                                                                  color: (state
                                                                          is AuthError)
                                                                      ? Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .error
                                                                      : Colors
                                                                          .grey
                                                                          .shade400,
                                                                ),
                                                              ),
                                                              focusedBorder:
                                                                  UnderlineInputBorder(
                                                                borderSide:
                                                                    BorderSide(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .primary,
                                                                  width: 2,
                                                                ),
                                                              ),
                                                              errorBorder:
                                                                  UnderlineInputBorder(
                                                                borderSide: BorderSide(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .error),
                                                              ),
                                                              focusedErrorBorder:
                                                                  UnderlineInputBorder(
                                                                borderSide:
                                                                    BorderSide(
                                                                  color: Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .error,
                                                                  width: 2,
                                                                ),
                                                              ),
                                                              filled: true,
                                                              fillColor: Colors
                                                                  .transparent,
                                                              contentPadding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          8.0,
                                                                      horizontal:
                                                                          0.0),
                                                              floatingLabelBehavior:
                                                                  FloatingLabelBehavior
                                                                      .auto,
                                                            ),
                                                            validator: (value) {
                                                              if (value ==
                                                                      null ||
                                                                  value
                                                                      .isEmpty) {
                                                                return 'Please enter your email';
                                                              }
                                                              if (!RegExp(
                                                                      r'^[^@]+@[^@]+\.[^@]+')
                                                                  .hasMatch(
                                                                      value)) {
                                                                return 'Please enter a valid email address';
                                                              }
                                                              return null;
                                                            },
                                                            onChanged: (value) {
                                                              // Optionally, check role on every change
                                                              // _checkIfStudentEmail(value.trim());
                                                            },
                                                          ),
                                                          const SizedBox(
                                                              height: 20),

                                                          // Password Field
                                                          AuthTextField(
                                                            controller:
                                                                _passwordController,
                                                            labelText:
                                                                'Password',
                                                            hintText:
                                                                'Enter your password',
                                                            obscureText:
                                                                !_isPasswordVisible,
                                                            prefixIcon: Icons
                                                                .lock_outlined,
                                                            suffixIcon:
                                                                IconButton(
                                                              icon: Icon(
                                                                _isPasswordVisible
                                                                    ? Icons
                                                                        .visibility
                                                                    : Icons
                                                                        .visibility_off,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                              onPressed: () {
                                                                setState(() {
                                                                  _isPasswordVisible =
                                                                      !_isPasswordVisible;
                                                                });
                                                              },
                                                            ),
                                                            validator: (value) {
                                                              if (value ==
                                                                      null ||
                                                                  value
                                                                      .isEmpty) {
                                                                return 'Please enter your password';
                                                              }
                                                              if (value.length <
                                                                  8) {
                                                                return 'Password must be at least 8 characters';
                                                              }
                                                              return null;
                                                            },
                                                            hasError: state
                                                                is AuthError,
                                                            showUnderline: true,
                                                          ),
                                                          const SizedBox(
                                                              height: 20),

                                                          // Login Button
                                                          Container(
                                                            height: 48,
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                              gradient:
                                                                  LinearGradient(
                                                                colors: [
                                                                  Colors.green[
                                                                      600]!,
                                                                  Colors.green[
                                                                      700]!,
                                                                ],
                                                              ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .green
                                                                      .withOpacity(
                                                                          0.3),
                                                                  blurRadius: 8,
                                                                  offset:
                                                                      const Offset(
                                                                          0, 4),
                                                                ),
                                                              ],
                                                            ),
                                                            child:
                                                                ElevatedButton(
                                                              onPressed: isLoading
                                                                  ? null
                                                                  : _handleLogin,
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    Colors
                                                                        .transparent,
                                                                shadowColor: Colors
                                                                    .transparent,
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              12),
                                                                ),
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                        vertical:
                                                                            12),
                                                              ),
                                                              child: isLoading
                                                                  ? const SizedBox(
                                                                      height:
                                                                          20,
                                                                      width: 20,
                                                                      child:
                                                                          CircularProgressIndicator(
                                                                        strokeWidth:
                                                                            2,
                                                                        valueColor:
                                                                            AlwaysStoppedAnimation<Color>(Colors.white),
                                                                      ),
                                                                    )
                                                                  : const Text(
                                                                      'LOGIN',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            16,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Colors
                                                                            .white,
                                                                      ),
                                                                    ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 16),
                                                          // Face Login Button
                                                          if (_checkingRole)
                                                            const Padding(
                                                              padding: EdgeInsets
                                                                  .symmetric(
                                                                      vertical:
                                                                          8.0),
                                                              child: Center(
                                                                  child:
                                                                      CircularProgressIndicator()),
                                                            ),
                                                          if (_roleError !=
                                                              null)
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          8.0),
                                                              child: Text(
                                                                _roleError!,
                                                                style: const TextStyle(
                                                                    color: Colors
                                                                        .red,
                                                                    fontSize:
                                                                        14),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                            ),
                                                          const SizedBox(
                                                              height: 12),

                                                          // Forgot Password Link
                                                          Center(
                                                            child: TextButton(
                                                              onPressed: () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder:
                                                                        (context) =>
                                                                            const ForgotPasswordPage(),
                                                                  ),
                                                                );
                                                              },
                                                              style: TextButton
                                                                  .styleFrom(
                                                                foregroundColor:
                                                                    Colors.green[
                                                                        600],
                                                                textStyle:
                                                                    const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                              child: const Text(
                                                                  'Forgot Password?'),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 12),

                                                          // Divider
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Divider(
                                                                  color: Colors
                                                                          .grey[
                                                                      300],
                                                                  thickness: 1,
                                                                ),
                                                              ),
                                                              Padding(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        12),
                                                                child: Text(
                                                                  'OR',
                                                                  style:
                                                                      TextStyle(
                                                                    color: Colors
                                                                            .grey[
                                                                        600],
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                child: Divider(
                                                                  color: Colors
                                                                          .grey[
                                                                      300],
                                                                  thickness: 1,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 12),

                                                          // Register Link
                                                          Center(
                                                            child: TextButton(
                                                              onPressed: () {
                                                                Navigator.pushReplacementNamed(
                                                                    context,
                                                                    AppRouter
                                                                        .register);
                                                              },
                                                              style: TextButton
                                                                  .styleFrom(
                                                                foregroundColor:
                                                                    Colors.green[
                                                                        600],
                                                                textStyle:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            14),
                                                              ),
                                                              child: RichText(
                                                                text: TextSpan(
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                              .green[
                                                                          600],
                                                                      fontSize:
                                                                          14),
                                                                  children: [
                                                                    const TextSpan(
                                                                        text:
                                                                            "Don't have an account? "),
                                                                    TextSpan(
                                                                      text:
                                                                          'Register',
                                                                      style: TextStyle(
                                                                          color: Colors.green[
                                                                              600],
                                                                          fontWeight:
                                                                              FontWeight.bold),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
