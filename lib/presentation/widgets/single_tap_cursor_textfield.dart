import 'dart:async';
import 'package:flutter/material.dart';

/// A custom TextField wrapper that prevents word selection on single tap.
/// Word selection is only allowed when the user explicitly long-presses.
class SingleTapCursorTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextAlignVertical? textAlignVertical;
  final bool autofocus;

  const SingleTapCursorTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.style,
    this.hintStyle,
    this.decoration,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.textAlignVertical,
    this.autofocus = false,
  });

  @override
  State<SingleTapCursorTextField> createState() => _SingleTapCursorTextFieldState();
}

class _SingleTapCursorTextFieldState extends State<SingleTapCursorTextField> {
  bool _isLongPressing = false;
  Timer? _longPressResetTimer;

  @override
  void dispose() {
    _longPressResetTimer?.cancel();
    super.dispose();
  }

  void _collapseSelectionIfSingleTap() {
    if (!_isLongPressing) {
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted && !_isLongPressing) {
          final sel = widget.controller.selection;
          if (!sel.isCollapsed && sel.isValid) {
            widget.controller.selection = TextSelection.collapsed(offset: sel.extentOffset);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDecoration = widget.decoration ??
        InputDecoration(
          hintText: widget.hintText,
          hintStyle: widget.hintStyle,
        );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (_) {
        _isLongPressing = true;
        _longPressResetTimer?.cancel();
      },
      onLongPressEnd: (_) {
        _longPressResetTimer?.cancel();
        _longPressResetTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) {
            _isLongPressing = false;
          }
        });
      },
      onLongPressCancel: () {
        _isLongPressing = false;
      },
      child: TextField(
        controller: widget.controller,
        textCapitalization: widget.textCapitalization,
        autofocus: widget.autofocus,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        expands: widget.expands,
        keyboardType: widget.keyboardType,
        textAlignVertical: widget.textAlignVertical,
        style: widget.style,
        onTap: _collapseSelectionIfSingleTap,
        decoration: effectiveDecoration,
      ),
    );
  }
}
