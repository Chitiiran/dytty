import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:dytty/core/theme/app_colors.dart';

class CategoryConfig extends Equatable {
  final String id;
  final String displayName;
  final String prompt;
  final int iconCodePoint;
  final String iconFontFamily;
  final int colorValue;
  final int order;
  final bool isDefault;
  final bool isArchived;

  const CategoryConfig({
    required this.id,
    required this.displayName,
    required this.prompt,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    required this.colorValue,
    required this.order,
    this.isDefault = false,
    this.isArchived = false,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: iconFontFamily);
  Color get color => Color(colorValue);

  Map<String, dynamic> toFirestore() => {
    'displayName': displayName,
    'prompt': prompt,
    'iconCodePoint': iconCodePoint,
    'iconFontFamily': iconFontFamily,
    'colorValue': colorValue,
    'order': order,
    'isDefault': isDefault,
    'isArchived': isArchived,
  };

  factory CategoryConfig.fromFirestore(String id, Map<String, dynamic> data) {
    return CategoryConfig(
      id: id,
      displayName: data['displayName'] as String? ?? id,
      prompt: data['prompt'] as String? ?? '',
      iconCodePoint:
          data['iconCodePoint'] as int? ?? Icons.category_rounded.codePoint,
      iconFontFamily: data['iconFontFamily'] as String? ?? 'MaterialIcons',
      colorValue: data['colorValue'] as int? ?? Colors.grey.value,
      order: data['order'] as int? ?? 0,
      isDefault: data['isDefault'] as bool? ?? false,
      isArchived: data['isArchived'] as bool? ?? false,
    );
  }

  CategoryConfig copyWith({
    String? displayName,
    String? prompt,
    int? iconCodePoint,
    String? iconFontFamily,
    int? colorValue,
    int? order,
    bool? isDefault,
    bool? isArchived,
  }) {
    return CategoryConfig(
      id: id,
      displayName: displayName ?? this.displayName,
      prompt: prompt ?? this.prompt,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      colorValue: colorValue ?? this.colorValue,
      order: order ?? this.order,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  /// The 5 default categories matching the original JournalCategory enum.
  static List<CategoryConfig> get defaults => [
    CategoryConfig(
      id: 'positive',
      displayName: 'Positive Things',
      prompt: 'What good things happened today?',
      iconCodePoint: Icons.wb_sunny_rounded.codePoint,
      colorValue: AppColors.positive.value,
      order: 0,
      isDefault: true,
    ),
    CategoryConfig(
      id: 'negative',
      displayName: 'Negative Things',
      prompt: 'What was challenging today?',
      iconCodePoint: Icons.cloud_rounded.codePoint,
      colorValue: AppColors.negative.value,
      order: 1,
      isDefault: true,
    ),
    CategoryConfig(
      id: 'gratitude',
      displayName: 'Gratitude',
      prompt: 'What are you grateful for today?',
      iconCodePoint: Icons.favorite_rounded.codePoint,
      colorValue: AppColors.gratitude.value,
      order: 2,
      isDefault: true,
    ),
    CategoryConfig(
      id: 'beauty',
      displayName: 'Beauty',
      prompt: 'What was beautiful today?',
      iconCodePoint: Icons.local_florist_rounded.codePoint,
      colorValue: AppColors.beauty.value,
      order: 3,
      isDefault: true,
    ),
    CategoryConfig(
      id: 'identity',
      displayName: 'Identity',
      prompt: 'Who are you based on your actions today?',
      iconCodePoint: Icons.fingerprint_rounded.codePoint,
      colorValue: AppColors.identity.value,
      order: 4,
      isDefault: true,
    ),
  ];

  @override
  List<Object?> get props => [
    id,
    displayName,
    prompt,
    iconCodePoint,
    iconFontFamily,
    colorValue,
    order,
    isDefault,
    isArchived,
  ];
}
