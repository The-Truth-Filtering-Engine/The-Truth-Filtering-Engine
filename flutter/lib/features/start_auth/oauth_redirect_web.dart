import 'package:web/web.dart' as web;

void redirectToOAuthUrl(String url) {
  web.window.location.assign(url);
}
