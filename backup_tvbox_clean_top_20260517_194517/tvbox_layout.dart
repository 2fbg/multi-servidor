part of 'main.dart';

bool isRestrictedIptvItemLocal(StreamItem item) {
  final text = '${item.title} ${item.group} ${item.url}'.toLowerCase();

  return text.contains('adult') ||
      text.contains('adulto') ||
      text.contains('xxx') ||
      text.contains('[hot]') ||
      text.contains('hot ') ||
      text.contains('| hot') ||
      text.contains('18+') ||
      text.contains('18 anos') ||
      text.contains('maior de idade') ||
      text.contains('porn') ||
      text.contains('sexo') ||
      text.contains('pornô') ||
      text.contains('erótico') ||
      text.contains('erotico');
}
``