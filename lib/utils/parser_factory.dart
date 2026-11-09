import 'package:manga_sonic/parser/base_parser.dart';
import 'package:manga_sonic/parser/manhuatop_parser.dart';
import 'package:manga_sonic/parser/asuracomic_parser.dart';
import 'package:manga_sonic/parser/manhuaplus_parser.dart';

BaseParser getParserForSite(String siteName) {
  final normalized = siteName
      .toLowerCase()
      .replaceAll(' ', '')
      .replaceAll('-', '');
  switch (normalized) {
    case 'manhuatop':
      return ManhuaTopParser();
    case 'asura':
    case 'asuracomic':
    case 'asurascan':
    case 'asurascans':
      return AsuraComicParser();
    case 'manhuaplus':
      return ManhuaPlusParser();
    default:
      throw Exception('Parser for site $siteName not implemented');
  }
}
