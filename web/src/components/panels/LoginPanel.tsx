import appLogoUrl from '../../../logo.png'

type Props = {
  authStatus: 'checking' | 'signedOut' | 'signedIn'
  authErrorMessage: string
  supabaseAvailable: boolean
  onSignInWithGoogle: () => void
  onSignInAsTemporaryAdmin: () => void
}

export function LoginPanel({
  authStatus,
  authErrorMessage,
  supabaseAvailable,
  onSignInWithGoogle,
  onSignInAsTemporaryAdmin,
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

        <button
          type="button"
          className="login-temp-button"
          onClick={onSignInAsTemporaryAdmin}
        >
          관리자 테스트 로그인
        </button>
      </section>
    </aside>
  )
}
