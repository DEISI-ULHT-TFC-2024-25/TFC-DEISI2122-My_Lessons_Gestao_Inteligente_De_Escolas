// models/team_input.dart
import 'phone_input.dart';

class TeamInput {
  String label;
  List<String> emails;
  List<PhoneInput> phones;

  TeamInput({
    this.label = '',
    List<String>? emails,
    List<PhoneInput>? phones,
  })  : emails = emails ?? [''],
        phones = phones ?? [PhoneInput()];

  factory TeamInput.fromJson(Map<String, dynamic> json) {
    return TeamInput(
      label: json['label'] as String,
      emails: List<String>.from(json['emails'] as List),
      phones: (json['phones'] as List)
          .map((p) => PhoneInput.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'emails': emails,
    'phones': phones.map((p) => p.toJson()).toList(),
  };
}
