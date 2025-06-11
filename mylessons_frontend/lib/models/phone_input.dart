// models/phone_input.dart
class PhoneInput {
  String number;
  String countryCode;
  bool canCall;
  bool canText;

  PhoneInput({
    this.number = '',
    this.countryCode = 'PT',
    this.canCall = false,
    this.canText = false,
  });

  factory PhoneInput.fromJson(Map<String, dynamic> json) {
    return PhoneInput(
      number: json['number'] as String,
      countryCode: json['country_code'] as String,
      canCall: json['capabilities']['call'] as bool,
      canText: json['capabilities']['text'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'country_code': countryCode,
    'capabilities': {
      'call': canCall,
      'text': canText,
    },
  };
}