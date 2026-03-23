import 'package:flutter/material.dart';

/// 自定义输入框组件
/// 样式类似于登录界面的圆角输入框
class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLength;
  final void Function(String)? onChanged;
  final bool enabled;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLength,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  String? _errorText;

  String? _validateField(String? value) {
    final error = widget.validator?.call(value);
    setState(() {
      _errorText = error;
    });
    return error;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _errorText != null;
    final isEmpty = widget.controller.text.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: widget.enabled
                ? const Color.fromARGB(255, 231, 242, 231)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: hasError ? Colors.red : const Color(0xFF90EE90),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (widget.prefixIcon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 15, right: 10),
                  child: Icon(widget.prefixIcon, color: Colors.grey, size: 20),
                ),
              ],
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  maxLength: widget.maxLength,
                  enabled: widget.enabled,
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (value) {
                    widget.onChanged?.call(value);
                    // 实时验证
                    if (_errorText != null) {
                      _validateField(value);
                    }
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    // Hide default FormField error text; we render a custom error below.
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                    // 只有在没有错误且输入框为空时才显示hintText
                    hintText: (hasError || !isEmpty) ? null : widget.hintText,
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: widget.prefixIcon != null ? 5 : 20,
                      vertical: 18,
                    ),
                    suffixIcon: widget.suffixIcon != null
                        ? Padding(
                            padding: const EdgeInsets.only(right: 15),
                            child: widget.suffixIcon,
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  validator: _validateField,
                ),
              ),
            ],
          ),
        ),
        // 显示验证错误信息
        Visibility(
          visible: hasError,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: Container(
            margin: const EdgeInsets.only(top: 5),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _errorText ?? '',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
