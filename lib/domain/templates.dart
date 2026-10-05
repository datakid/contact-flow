import '../models/person.dart';
import 'names.dart';

class MessageTemplate {
  final String text;
  const MessageTemplate(this.text);

  static const tokens = ['{first}', '{last}', '{name}', '{company}'];

  String render(Person p) {
    final parts = NameParts.of(p.name);
    final first = parts.first.isEmpty ? p.name.trim() : parts.first;
    return text
        .replaceAll('{first}', first)
        .replaceAll('{last}', parts.last)
        .replaceAll('{name}', p.name.trim())
        .replaceAll('{company}', p.org.trim())
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAllMapped(RegExp(r' +([,.!?،؟])'), (m) => m.group(1)!)
        .trim();
  }

  bool get usesTokens => tokens.any(text.contains);
}
