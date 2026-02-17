import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:z/providers/auth_provider.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  bool _isLoading = false;
  bool _isResending = false;

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      final authService = ref.read(authServiceProvider);
      // We need the email to resend. We'll get it from a provider we'll create.
      final email = ref.read(pendingEmailProvider);
      if (email != null) {
        await authService.resendEmailConfirmation(email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Confirmation email resent!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to resend: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);

      // Try to sign in with stored credentials if available
      final email = ref.read(pendingEmailProvider);
      final password = ref.read(pendingPasswordProvider);

      if (email != null && password != null) {
        await authService.signInWithEmail(email: email, password: password);
        // If successful, the auth state change will trigger redirect
        // Clear pending providers
        ref.read(pendingEmailProvider.notifier).state = null;
        ref.read(pendingPasswordProvider.notifier).state = null;
      } else {
        // Fallback to simpler check if we don't have password
        await authService.refreshUserSession();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to continue')),
          );
          context.go('/login');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification check failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(pendingEmailProvider) ?? 'your email';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              Text(
                'Verify your email',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'We\'ve sent a confirmation email to:',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                email,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              const Text(
                'Please check your inbox and click the verification link to continue.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _checkStatus,
                      child: const Text('I\'ve confirmed my email'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isResending ? null : _resendEmail,
                      child: Text(_isResending ? 'Sending...' : 'Resend email'),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(pendingEmailProvider.notifier).state = null;
                        context.go('/login');
                      },
                      child: const Text('Back to Login'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
