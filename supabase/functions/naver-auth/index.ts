// supabase/functions/naver-auth/index.ts
// Naver OAuth → Supabase 세션 교환 Edge Function
//
// 환경변수 (Supabase 대시보드 > Edge Functions > Secrets에 설정):
//   NAVER_CLIENT_ID       : 네이버 개발자센터 앱의 Client ID
//   NAVER_CLIENT_SECRET   : 네이버 개발자센터 앱의 Client Secret
//   SUPABASE_URL          : 자동 주입
//   SUPABASE_SERVICE_ROLE_KEY : 자동 주입 (또는 수동 설정)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

interface NaverTokenResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: string;
  error?: string;
  error_description?: string;
}

interface NaverUserResponse {
  resultcode: string;
  message: string;
  response: {
    id: string;
    email: string;
    name: string;
    nickname?: string;
    profile_image?: string;
  };
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { code, state, redirectUri } = await req.json();

    if (!code) {
      return new Response(
        JSON.stringify({ error: 'code is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const naverClientId = Deno.env.get('NAVER_CLIENT_ID') ?? 'MUUADsIYWROs07ZDyToI';
    const naverClientSecret = Deno.env.get('NAVER_CLIENT_SECRET') ?? 'anh11zkJgj';
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? 'https://trhwelbdnhhpldpkrxmp.supabase.co';
    const supabaseServiceKey =
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRyaHdlbGJkbmhocGxkcGtyeG1wIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Njk0Mzg0NCwiZXhwIjoyMDkyNTE5ODQ0fQ.gWxEBUTxaLBdUGM-5KwaZpM7KJX01qN5USepm5fa-2M';

    if (!naverClientId || !naverClientSecret) {
      return new Response(
        JSON.stringify({ error: 'Naver credentials not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── Step 1: 네이버 Access Token 교환 ─────────────────────────
    const tokenParams = new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: naverClientId,
      client_secret: naverClientSecret,
      code,
      state: state ?? '',
    });

    const tokenRes = await fetch(
      `https://nid.naver.com/oauth2.0/token?${tokenParams.toString()}`,
      { method: 'GET' },
    );

    const tokenData: NaverTokenResponse = await tokenRes.json();

    if (tokenData.error || !tokenData.access_token) {
      return new Response(
        JSON.stringify({
          error: 'Failed to get Naver access token',
          detail: tokenData.error_description ?? tokenData.error,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── Step 2: 네이버 사용자 정보 조회 ──────────────────────────
    const userRes = await fetch('https://openapi.naver.com/v1/nid/me', {
      headers: { Authorization: `Bearer ${tokenData.access_token}` },
    });

    const userData: NaverUserResponse = await userRes.json();

    if (userData.resultcode !== '00') {
      return new Response(
        JSON.stringify({ error: 'Failed to get Naver user info', detail: userData.message }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const naverUser = userData.response;
    const email = naverUser.email;
    const naverId = naverUser.id;

    if (!email) {
      return new Response(
        JSON.stringify({ error: 'Naver account has no email. Please set email in Naver profile.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── Step 3: Supabase 사용자 생성 or 조회 ─────────────────────
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // 이미 존재하는 사용자인지 확인
    const { data: existingUsers } = await supabase.auth.admin.listUsers();
    const existingUser = existingUsers?.users?.find((u) => u.email === email);

    let userId: string;

    if (existingUser) {
      userId = existingUser.id;

      // 메타데이터 업데이트 (네이버 ID 동기화)
      await supabase.auth.admin.updateUserById(userId, {
        user_metadata: {
          ...existingUser.user_metadata,
          naver_id: naverId,
          full_name: naverUser.name,
          avatar_url: naverUser.profile_image,
          provider: 'naver',
        },
      });
    } else {
      // 신규 사용자 생성
      const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
        email,
        email_confirm: true,
        user_metadata: {
          naver_id: naverId,
          full_name: naverUser.name,
          nickname: naverUser.nickname ?? naverUser.name,
          avatar_url: naverUser.profile_image,
          provider: 'naver',
        },
      });

      if (createError || !newUser?.user) {
        return new Response(
          JSON.stringify({ error: 'Failed to create user', detail: createError?.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }

      userId = newUser.user.id;
    }

    // ── Step 4: 해당 유저의 매직링크(OTP) 세션 생성 ──────────────
    // admin.generateLink → Flutter에서 verifyOtp로 세션 교환
    const { data: linkData, error: linkError } = await supabase.auth.admin.generateLink({
      type: 'magiclink',
      email,
      options: {
        data: { provider: 'naver', naver_id: naverId },
      },
    });

    if (linkError || !linkData?.properties?.hashed_token) {
      return new Response(
        JSON.stringify({ error: 'Failed to generate session link', detail: linkError?.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Flutter 클라이언트에 토큰 반환 → verifyOtp('email', token) 으로 세션 완성
    return new Response(
      JSON.stringify({
        success: true,
        email,
        token: linkData.properties.hashed_token,
        user: {
          id: userId,
          name: naverUser.name,
          email,
          avatar_url: naverUser.profile_image,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  } catch (err) {
    console.error('naver-auth error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error', detail: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
