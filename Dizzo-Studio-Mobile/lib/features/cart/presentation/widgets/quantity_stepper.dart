import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/widgets.dart';

/// − 12 +, with the number tappable to type a large quantity.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 1000});

  final int value;

  /// Null disables the stepper.
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;

  void _set(int v) {
    if (onChanged == null || v < min || v > max || v == value) return;
    HapticFeedback.selectionClick();
    onChanged!(v);
  }

  Future<void> _type(BuildContext context) async {
    final v = await showAppBottomSheet<int>(
      context,
      title: context.l10n.cartQuantity,
      builder: (_) => _QuantityInput(initial: value, min: min, max: max),
    );
    if (v != null) _set(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    Widget button(IconData icon, String tip, int next, bool can) => SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        tooltip: tip,
        padding: EdgeInsets.zero,
        onPressed: enabled && can ? () => _set(next) : null,
        icon: Icon(icon, size: 20),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.brMd,
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, context.l10n.cartDecrease, value - 1, value > min),
          InkWell(
            onTap: enabled ? () => _type(context) : null,
            borderRadius: Radii.brSm,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '$value',
                    key: const ValueKey('quantity'),
                    style: context.text.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: enabled ? c.ink : c.inkSubtle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          button(Icons.add_rounded, context.l10n.cartIncrease, value + 1, value < max),
        ],
      ),
    );
  }
}

class _QuantityInput extends StatefulWidget {
  const _QuantityInput({required this.initial, required this.min, required this.max});

  final int initial;
  final int min;
  final int max;

  @override
  State<_QuantityInput> createState() => _QuantityInputState();
}

class _QuantityInputState extends State<_QuantityInput> {
  late final _ctrl = TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = int.tryParse(_ctrl.text.trim());
    if (v == null || v < widget.min || v > widget.max) {
      setState(() => _error = context.l10n.cartQuantityRange(widget.min, widget.max));
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: InputDecoration(labelText: context.l10n.cartQuantityPieces, errorText: _error),
          onSubmitted: (_) => _submit(),
        ),
        Gap.lg,
        AppButton(label: context.l10n.commonSave, onPressed: _submit),
      ],
    );
  }
}
