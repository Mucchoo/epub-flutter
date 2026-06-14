import 'package:path/path.dart' as p;

String normalizePath(String raw) {
  final stripped = raw.startsWith('/') ? raw.substring(1) : raw;
  final normalized = p.posix.normalize(stripped);
  return normalized == '.' ? '' : normalized;
}

String resolveHref(String base, String href) {
  if (href.startsWith('http://') || href.startsWith('https://')) return href;
  final uri = Uri.parse(href);
  final baseDir = p.posix.dirname(base);
  final joined = baseDir.isEmpty || baseDir == '.'
      ? uri.path
      : '$baseDir/${uri.path}';
  return normalizePath(joined);
}
