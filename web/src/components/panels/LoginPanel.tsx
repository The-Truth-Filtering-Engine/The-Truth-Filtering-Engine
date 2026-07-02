import appLogoUrl from '../../../logo.png'

type Props = {
  authStatus: 'checking' | 'signedOut' | 'signedIn'
  authErrorMessage: string
  supabaseAvailable: boolean
  onSignInWithGoogle: () => void
}

export function LoginPanel({
  authStatus,
  authErrorMessage,
  supabaseAvailable,
  onSignInWithGoogle,
}: Props) {
  return (
    <aside className="restaurant-panel login-panel" aria-label="로그인">
      <section className="login-panel-body">
        <div className="login-panel-header">
          <div className="login-mark" aria-hidden="true">
            <img src={appLogoUrl} alt="" />
          </div>
          <div>
            <p>Sign in</p>
            <h2>로그인이 필요합니다</h2>
          </div>
        </div>

        {/* SEO 및 사용자 인트로 카드 */}
        <div
          className="login-seo-info"
          style={{
            marginTop: '-10px',
            marginBottom: '24px',
            padding: '16px',
            borderRadius: '12px',
            background: 'var(--color-bg-default)',
            border: '1px solid var(--color-border-subtle)',
            boxShadow: 'var(--shadow-sm)'
          }}
        >
          <h1
            style={{
              fontSize: '14px',
              fontWeight: 800,
              color: 'var(--color-text-primary)',
              margin: '0 0 8px 0'
            }}
          >
            진실의 입 | 광고 리뷰 판별 AI
          </h1>
          <p
            style={{
              fontSize: '12.5px',
              color: 'var(--color-text-secondary)',
              lineHeight: '1.5',
              margin: 0
            }}
          >
            맛집 블로그 리뷰가 협찬/광고글인지 인공지능 AI 분석을 통해 정확하게 판별해주는 서비스입니다.
            진실의 입에서 가짜 광고성 리뷰를 걸러내고, 진짜 내돈내산 후기들만 스마트하게 판별해 보세요.
          </p>
        </div>

        <button
          type="button"
          className="login-oauth-button"
          disabled={!supabaseAvailable || authStatus === 'checking'}
          onClick={onSignInWithGoogle}
        >
          <span aria-hidden="true">G</span>
          Google로 계속하기
        </button>

        {authErrorMessage && (
          <p className="login-error-message">{authErrorMessage}</p>
        )}

        <div className="login-divider" aria-hidden="true" />

      </section>
    </aside>
  )
}
