enum BlogSourcePlatform {
  naver('네이버'),
  kakao('카카오'),
  google('구글'),
  external('원문');

  final String label;

  const BlogSourcePlatform(this.label);
}

BlogSourcePlatform detectBlogSourcePlatform(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');

  if (_isNaverHost(host)) {
    return BlogSourcePlatform.naver;
  }
  if (_isKakaoHost(host)) {
    return BlogSourcePlatform.kakao;
  }
  if (_isGoogleHost(host, uri.path.toLowerCase())) {
    return BlogSourcePlatform.google;
  }
  return BlogSourcePlatform.external;
}

bool _isNaverHost(String host) {
  return host == 'blog.naver.com' ||
      host == 'm.blog.naver.com' ||
      host == 'cafe.naver.com' ||
      host == 'm.cafe.naver.com';
}

bool _isKakaoHost(String host) {
  return host == 'tistory.com' ||
      host.endsWith('.tistory.com') ||
      host == 'brunch.co.kr' ||
      host == 'brunchstory.co.kr' ||
      host == 'cafe.daum.net' ||
      host == 'm.cafe.daum.net';
}

bool _isGoogleHost(String host, String path) {
  return host == 'youtube.com' ||
      host == 'm.youtube.com' ||
      host == 'youtu.be' ||
      host == 'blogger.com' ||
      host.endsWith('.blogger.com') ||
      host == 'blogspot.com' ||
      host.endsWith('.blogspot.com') ||
      host == 'maps.app.goo.gl' ||
      (host == 'google.com' && path.startsWith('/maps')) ||
      (host.endsWith('.google.com') && path.startsWith('/maps')) ||
      (host.endsWith('.google.co.kr') && path.startsWith('/maps'));
}
