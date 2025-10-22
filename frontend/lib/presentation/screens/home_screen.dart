import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// A clean and modern home screen for the Ambulance Tracking System (ATS) app.
///
/// This screen serves as the initial landing page, providing users with
/// clear options to either log in or sign up. It features an animated logo,
/// the app's name, and a motivational slogan.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _goToLogin(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginScreen()));
  }

  void _goToSignup(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (c) => const SignupScreen()));
  }

  Widget _buildNavBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Row(
        children: [
          // App logo
          Row(
            children: [
              Image.asset('assets/ambulance.png', height: 28, width: 28, errorBuilder: (_, __, ___) => Icon(Icons.local_hospital, color: Color(0xFF007AFF), size: 28)),
              const SizedBox(width: 8),
              const Text('ATS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          const Spacer(),
          // Show Login/Signup OR Logout based on auth state
          FutureBuilder<String?>(
            future: AuthService.getToken(),
            builder: (context, snapshot) {
              final hasToken = snapshot.data != null;
              if (hasToken) {
                return Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await AuthService.logout();
                        // Rebuild the UI; in a real app you'd use a provider/state management.
                        if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  TextButton(
                    onPressed: () => _goToLogin(context),
                    child: const Text('Login'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _goToSignup(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                    ),
                    child: const Text('Sign Up'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24),
      child: isWide
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Track Ambulances Instantly', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text('Live map, instant alerts, easy login.', style: TextStyle(fontSize: 16, color: Colors.black54)),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _goToSignup(context),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
                              child: Text('Get Started'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () => _goToLogin(context),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
                              child: Text('Login'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Center(
                    child: Image.asset('assets/hero_ambulance.png', height: 180, errorBuilder: (_, __, ___) => Icon(Icons.local_hospital, size: 120, color: Colors.blue.shade100)),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('Track Ambulances Instantly', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Live map, instant alerts, easy login.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => _goToSignup(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
                    child: Text('Get Started'),
                  ),
                ),
                const SizedBox(height: 10),
                Image.asset('assets/hero_ambulance.png', height: 120, errorBuilder: (_, __, ___) => Icon(Icons.local_hospital, size: 80, color: Colors.blue.shade100)),
              ],
            ),
    );
  }

  

  Widget _buildFeatureCard(IconData icon, String title, String subtitle) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 28, color: const Color(0xFF007AFF)), const SizedBox(width: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatures(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    final cards = [
      _buildFeatureCard(Icons.gps_fixed, 'Real-time Tracking', 'Live ambulance locations on the map'),
      _buildFeatureCard(Icons.notifications_active, 'Proximity Alerts', 'Notify nearby officers when close'),
      _buildFeatureCard(Icons.security, 'Secure Auth', 'JWT-based authentication for users'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          isWide ? Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: c))).toList()) : Column(children: cards.map((c) => Padding(padding: const EdgeInsets.symmetric(vertical: 6.0), child: c)).toList()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNavBar(context),
              _buildHero(context),
              const Divider(),
              const SizedBox(height: 8),
              _buildFeatures(context),
              const SizedBox(height: 32),
              // Footer
              Center(child: Text('© ${DateTime.now().year} ATS - Ambulance Tracking System', style: TextStyle(color: Colors.black45))),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

