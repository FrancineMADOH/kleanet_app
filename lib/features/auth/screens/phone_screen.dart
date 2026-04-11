// Écran saisie du numéro de téléphone (étape 1 du flow OTP).
//
// L'utilisateur saisit son numéro local (9 chiffres commençant par 6) ou
// un numéro déjà en E.164. PhoneUtils.normalize() ramène tout à `+237...`.
// Sur submit → AuthProvider.sendOtp → si OK, navigation vers /auth/otp.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/phone_utils.dart';
import '../providers/auth_provider.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _localError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Valide le numéro saisi et déclenche l'envoi OTP.
  /// Le bouton est désactivé pendant l'appel réseau (otpStatus == sending).
  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final e164 = PhoneUtils.normalize(_controller.text);
    if (e164 == null) {
      setState(() => _localError = 'Numéro invalide.');
      return;
    }

    final provider = context.read<AuthProvider>();
    final ok = await provider.sendOtp(e164);
    if (!mounted) return;
    if (ok) {
      context.push(Routes.authOtp);
    } else {
      setState(() {
        _localError = provider.errorMessage ?? 'Envoi impossible. Réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpStatus = context.select<AuthProvider, OtpFlowStatus>(
      (p) => p.otpStatus,
    );
    final isSending = otpStatus == OtpFlowStatus.sending;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    'Votre numéro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'On vous envoie un code à 6 chiffres par SMS pour confirmer.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Champ numéro — fond blanc pour contraste sur le gradient.
                  TextFormField(
                    controller: _controller,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    enabled: !isSending,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                    ],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      prefixText: '+237  ',
                      prefixStyle: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                      hintText: '6 99 00 00 00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Entrez votre numéro.';
                      }
                      return null;
                    },
                  ),
                  if (_localError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _localError!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSending ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    child: isSending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.primary),
                            ),
                          )
                        : const Text('Recevoir le code'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
