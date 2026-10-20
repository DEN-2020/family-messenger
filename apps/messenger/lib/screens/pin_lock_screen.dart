import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// Local 4-digit PIN lock screen protecting access to the messenger on the device.
class PinLockScreen extends StatefulWidget {
  final AppPreferencesController prefs;
  final String userDisplayName;

  const PinLockScreen({
    super.key,
    required this.prefs,
    required this.userDisplayName,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _entered = '';
  String? _error;

  Future<void> _onDigit(String digit) async {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == 4) {
      final ok = await widget.prefs.unlockWithPin(_entered);
      if (!ok && mounted) {
        setState(() {
          _entered = '';
          _error = 'Неверный PIN-код. Попробуйте ещё раз.';
        });
      }
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(FamilySpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FamilyAvatar(
                    title: widget.userDisplayName,
                    radius: 30,
                    showProtectedDot: true,
                  ),
                  const SizedBox(height: FamilySpacing.md),
                  Text(
                    'Введите PIN-код',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: FamilySpacing.xs),
                  Text(
                    'Привет, ${widget.userDisplayName}!',
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: FamilySpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final filled = index < _entered.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? palette.primaryPine
                              : palette.borderSubtle,
                        ),
                      );
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: FamilySpacing.md),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.dangerFg,
                      ),
                    ),
                  ],
                  const SizedBox(height: FamilySpacing.xl),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                        _PinKeyButton(
                          label: d,
                          onTap: () => _onDigit(d),
                        ),
                      const SizedBox(width: 68, height: 56),
                      _PinKeyButton(
                        label: '0',
                        onTap: () => _onDigit('0'),
                      ),
                      SizedBox(
                        width: 68,
                        height: 56,
                        child: IconButton(
                          tooltip: 'Стереть',
                          onPressed: _onBackspace,
                          icon: const Icon(Icons.backspace_outlined),
                        ),
                      ),
                    ],
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

class _PinKeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PinKeyButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return SizedBox(
      width: 68,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: palette.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
    );
  }
}
