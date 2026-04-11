// Écran saisie du code OTP (étape 2 du flow OTP).
//
// UX : 6 cases individuelles (auto-focus next). Countdown 5min affiché —
// à l'expiration, le bouton "Renvoyer le code" s'active. Après 5 échecs
// consécutifs, AuthProvider bascule en `locked` et on affiche un écran
// d'attente 10min (géré par le provider via SharedPreferences).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/phone_utils.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // 6 contrôleurs indépendants = 6 cases individuelles.
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focuses = List.generate(6, (_) => FocusNode());

  /// Countdown "renvoyer dans X:XX" — 5min depuis l'entrée sur l'écran.
  static const _resendWindow = Duration(minutes: 5);
  late DateTime _resendAvailableAt;
  Timer? _ticker;
  Duration _remaining = _resendWindow;

  @override
  void initState() {
    super.initState();
    _resetCountdown();
  }

  void _resetCountdown() {
    _resendAvailableAt = DateTime.now().add(_resendWindow);
    _remaining = _resendWindow;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _resendAvailableAt.difference(DateTime.now());
      if (!mounted) return;
      if (left.isNegative || left == Duration.zero) {
        setState(() => _remaining = Duration.zero);
        _ticker?.cancel();
      } else {
        setState(() => _remaining = left);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focuses) {
      f.dispose();
    }
    super.dispose();
  }

  /// Concatène les 6 cases et tente la vérification.
  /// Appelé automatiquement dès que la 6e case est remplie. Garde anti-
  /// réentrance : si un appel est déjà en cours, on ignore le suivant —
  /// évite les double-submits en cas de saisie rapide.
  Future<void> _tryVerify() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) return;

    final provider = context.read<AuthProvider>();
    if (provider.otpStatus == OtpFlowStatus.verifying) return;
    final ok = await provider.verifyOtp(code);
    if (!mounted) return;
    if (!ok) {
      // Échec → vide les cases et replace le focus au début.
      for (final c in _controllers) {
        c.clear();
      }
      _focuses.first.requestFocus();
    }
    // Succès → le router bascule automatiquement via AuthStatus.authenticated.
  }

  Future<void> _resend() async {
    final provider = context.read<AuthProvider>();
    final phone = provider.pendingPhone;
    if (phone == null) {
      context.pop();
      return;
    }
    final ok = await provider.sendOtp(phone);
    if (!mounted) return;
    if (ok) {
      _resetCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nouveau code envoyé.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuthProvider>();
    final otpStatus = provider.otpStatus;
    final isVerifying = otpStatus == OtpFlowStatus.verifying;
    final isLocked = otpStatus == OtpFlowStatus.locked;
    final phone = provider.pendingPhone;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Text(
                  'Entrez le code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  phone == null
                      ? 'Un code à 6 chiffres vient d\'être envoyé.'
                      : 'Code envoyé au ${PhoneUtils.formatDisplay(phone)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                if (isLocked)
                  _LockedNotice(until: provider.lockedUntil)
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) => _buildBox(i)),
                  ),
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
                const SizedBox(height: 24),
                if (isVerifying)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                const SizedBox(height: 24),
                if (!isLocked)
                  Center(
                    child: _remaining == Duration.zero
                        ? TextButton(
                            onPressed: _resend,
                            child: const Text(
                              'Renvoyer le code',
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : Text(
                            'Renvoyer dans ${_formatRemaining(_remaining)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
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

  /// Construit une case unique — gère auto-advance et backspace vers
  /// la case précédente.
  Widget _buildBox(int index) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focuses[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focuses[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focuses[index - 1].requestFocus();
          }
          if (index == 5 && value.isNotEmpty) {
            _tryVerify();
          }
        },
      ),
    );
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _LockedNotice extends StatelessWidget {
  const _LockedNotice({required this.until});

  final DateTime? until;

  @override
  Widget build(BuildContext context) {
    final h = until?.hour.toString().padLeft(2, '0') ?? '--';
    final m = until?.minute.toString().padLeft(2, '0') ?? '--';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_clock, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          Text(
            'Trop de tentatives. Réessayez à $h:$m.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
