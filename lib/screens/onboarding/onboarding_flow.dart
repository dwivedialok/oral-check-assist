import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';
import 'how_it_works_screen.dart';
import 'privacy_screen.dart';

/// Manages the onboarding flow for first-time users
class OnboardingFlow extends StatefulWidget {
  final VoidCallback onComplete;
  final void Function(Locale locale)? onLocaleChanged;

  const OnboardingFlow({
    super.key,
    required this.onComplete,
    this.onLocaleChanged,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _currentStep = 0;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return WelcomeScreen(
          onLocaleChanged: widget.onLocaleChanged,
          onContinue: () => setState(() => _currentStep = 1),
        );
      case 1:
        return HowItWorksScreen(
          onLocaleChanged: widget.onLocaleChanged,
          onContinue: () => setState(() => _currentStep = 2),
        );
      case 2:
        return PrivacyScreen(
          onLocaleChanged: widget.onLocaleChanged,
          onAccept: _completeOnboarding,
        );
      default:
        return WelcomeScreen(
          onLocaleChanged: widget.onLocaleChanged,
          onContinue: () => setState(() => _currentStep = 1),
        );
    }
  }
}

/// Helper to check if onboarding is complete
Future<bool> isOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_complete') ?? false;
}
