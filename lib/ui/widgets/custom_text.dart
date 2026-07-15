import 'package:flutter/material.dart';
import 'package:call_tracker/ui/common/app_colors.dart';

class CustomText extends StatelessWidget {
  const CustomText(
    this.text, {
    super.key,
    this.textColor,
    this.fontSize,
    this.fontWeight,
    this.maxLines,
    this.textAlign,
    this.height,
  });

  final String text;
  final Color? textColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final int? maxLines;
  final TextAlign? textAlign;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      style: TextStyle(
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.w500,
        color: textColor ?? AppColors.textColor,
        height: height,
      ),
    );
  }

  factory CustomText.headline({required String text, Color? textColor, TextAlign? textAlign}) =>
      CustomText(text, fontSize: 28, fontWeight: FontWeight.bold, textColor: textColor, textAlign: textAlign);

  factory CustomText.title({required String text, Color? textColor, int? maxLines, TextAlign? textAlign, double? fontSize}) =>
      CustomText(text, fontSize: fontSize ?? 20, fontWeight: FontWeight.bold, textColor: textColor, maxLines: maxLines, textAlign: textAlign);

  factory CustomText.subtitle({required String text, Color? textColor, int? maxLines}) =>
      CustomText(text, fontSize: 13, fontWeight: FontWeight.w500, textColor: textColor ?? AppColors.secondaryColor, maxLines: maxLines);

  factory CustomText.bodyBold({required String text, Color? textColor, int? maxLines, double? fontSize, TextAlign? textAlign}) =>
      CustomText(text, fontSize: fontSize ?? 16, fontWeight: FontWeight.w700, textColor: textColor, maxLines: maxLines, textAlign: textAlign);

  factory CustomText.body({required String text, Color? textColor, int? maxLines, double? fontSize, TextAlign? textAlign}) =>
      CustomText(text, fontSize: fontSize ?? 14, fontWeight: FontWeight.w500, textColor: textColor, maxLines: maxLines, textAlign: textAlign);

  factory CustomText.caption({required String text, Color? textColor, TextAlign? textAlign}) =>
      CustomText(text, fontSize: 12, fontWeight: FontWeight.w500, textColor: textColor ?? AppColors.secondaryColor, textAlign: textAlign);
}
