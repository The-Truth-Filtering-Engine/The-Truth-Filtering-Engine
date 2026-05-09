export 'kakao_map_view_stub.dart'
    if (dart.library.html) 'kakao_map_view_web.dart'
    if (dart.library.io) 'kakao_map_view_mobile.dart';
