import 'package:flutter/material.dart';
import 'login_screen.dart'; // Import for navigation
import 'signup_screen.dart'; // Import for navigation

/// A clean and modern home screen for the Ambulance Tracking System (ATS) app.
///
/// This screen serves as the initial landing page, providing users with
/// clear options to either log in or sign up. It features an animated logo,
/// the app's name, and a motivational slogan.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// We use TickerProviderStateMixin to enable animation controllers.
class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Animation controllers are used to manage the timing of animations.
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize the controller for a 1.5-second animation.
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Create a fade-in animation.
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    // Create a slide-up animation for the buttons.
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5), // Start 50% down from the final position
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Start the animation as soon as the screen loads.
    _controller.forward();
  }

  @override
  void dispose() {
    // It's important to dispose of the controller to free up resources.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Wrap the logo and text in a FadeTransition for a smooth entrance.
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // --- Enhanced UI: App Logo ---
                      // A heart icon inside an emergency icon to represent saving lives.
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.emergency_outlined,
                            size: 120,
                            color: Color(0xFF007AFF),
                          ),
                          Icon(
                            Icons.favorite,
                            size: 50,
                            color: Colors.red.shade400,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // --- App Name ---
                      const Text(
                        'ATS',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1D2A3A),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // --- App Slogan ---
                      const Text(
                        'Your Partner in Saving Lives',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 70),

                // --- Animation: Wrap buttons in a SlideTransition ---
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // --- Login Button with Navigation ---
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Navigate to the LoginScreen when tapped.
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                            ),
                            child: const Text(
                              'LOGIN',
                              style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // --- Sign Up Button with Navigation ---
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              // Navigate to the SignupScreen when tapped.
                               Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SignupScreen()),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFF007AFF), width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'SIGN UP',
                              style: TextStyle(fontSize: 16, color: Color(0xFF007AFF), fontWeight: FontWeight.bold),
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
    );
  }
}

