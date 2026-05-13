Uri? mobileBlogReviewUri(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;

  final withScheme = trimmed.startsWith('//') ? 'https:$trimmed' : trimmed;
  var uri = Uri.tryParse(withScheme);
  if (uri == null) return null;

  if (uri.host.isEmpty && !withScheme.contains('://')) {
    uri = Uri.tryParse('https://$withScheme');
    if (uri == null) return null;
  }

  if (!_isNaverBlogHost(uri.host)) return uri;

  final query = <String, String>{
    for (final entry in uri.queryParameters.entries)
      entry.key.toLowerCase(): entry.value,
  };
  final blogId = query['blogid'];
  final logNo = query['logno'];

  if (blogId != null &&
      blogId.isNotEmpty &&
      logNo != null &&
      logNo.isNotEmpty) {
    return Uri.https('m.blog.naver.com', '/$blogId/$logNo');
  }

  return uri.replace(
    scheme:
        uri.scheme == 'http' || uri.scheme == 'https' ? 'https' : uri.scheme,
    host: 'm.blog.naver.com',
  );
}

bool _isNaverBlogHost(String host) {
  final normalized = host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  return normalized == 'blog.naver.com' || normalized == 'm.blog.naver.com';
}
