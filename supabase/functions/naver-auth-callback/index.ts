// supabase/functions/naver-auth-callback/index.ts
// 네이버 로그인 후 리다이렉트 콜백 처리
// 역할: 네이버가 리다이렉트한 URL을 받아서 Flutter WebView가 캐치할 수 있도록 그대로 전달

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const code = url.searchParams.get('code');
  const state = url.searchParams.get('state');
  const error = url.searchParams.get('error');

  if (error) {
    return new Response(
      `<html><body><h3>로그인 취소됨</h3><p>${error}</p></body></html>`,
      {
        status: 200,
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      },
    );
  }

  if (!code) {
    return new Response(
      `<html><body><h3>오류</h3><p>code 파라미터가 없습니다.</p></body></html>`,
      {
        status: 400,
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      },
    );
  }

  // WebView의 NavigationDelegate가 이 URL을 캐치합니다.
  // 실제로 이 페이지가 로드되지 않고 Flutter가 가로채므로
  // 단순한 로딩 HTML만 반환합니다.
  return new Response(
    `<!DOCTYPE html>
    <html>
      <head><meta charset="utf-8"><title>로그인 처리 중...</title></head>
      <body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;">
        <div style="text-align:center;">
          <div style="width:40px;height:40px;border:4px solid #03C75A;border-top:4px solid transparent;border-radius:50%;animation:spin 1s linear infinite;margin:0 auto 16px;"></div>
          <p>네이버 로그인 처리 중...</p>
        </div>
        <style>@keyframes spin{0%{transform:rotate(0deg)}100%{transform:rotate(360deg)}}</style>
      </body>
    </html>`,
    {
      status: 200,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
    },
  );
});
