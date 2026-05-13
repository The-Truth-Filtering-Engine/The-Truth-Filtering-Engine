import appLogoUrl from '../../../logo.png'

type Props = {
  authStatus: 'checking' | 'signedOut' | 'signedIn'
  authErrorMessage: string
  supabaseAvailable: boolean
  onSignInWithGoogle: () => void
  onSignInWithTestAccount: () => void
}

export function LoginPanel({
  authStatus,
  authErrorMessage,
  supabaseAvailable,
  onSignInWithGoogle,
  onSignInWithTestAccount,
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
          className="login-test-account-button"
          onClick={onSignInWithTestAccount}
        >
          테스트 계정으로 계속하기
        </button>
      </section>
    </aside>
  )
}
