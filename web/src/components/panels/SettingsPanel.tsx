import {
  AlertCircle,
  Coins,
  Crown,
  LoaderCircle,
  LogOut,
  RefreshCw,
  Settings,
  UserRound,
  X,
} from 'lucide-react'
import { type UserProfile } from '../../api/user'

type UserProfileState = {
  profile: UserProfile | null
  isLoading: boolean
  isSaving: boolean
  errorMessage: string
  hasLoaded: boolean
}

type Props = {
  userProfileState: UserProfileState
  isTemporaryAdmin: boolean
  onClose: () => void
  onTogglePremium: () => void
  onChargeCoins: (amount: number) => void
  onSignOut: () => void
  onRetryLoadProfile: () => void
}

export function SettingsPanel({
  userProfileState,
  isTemporaryAdmin,
  onClose,
  onTogglePremium,
  onChargeCoins,
  onSignOut,
  onRetryLoadProfile,
}: Props) {
  return (
    <aside className="restaurant-panel settings-panel" aria-label="설정">
      <button
        type="button"
        className="panel-close-button"
        aria-label="설정 닫기"
        onClick={onClose}
      >
        <X aria-hidden="true" size={19} strokeWidth={2.2} />
      </button>

      <section className="bookmark-panel-body settings-panel-body">
        <div className="bookmark-panel-header settings-panel-header">
          <Settings aria-hidden="true" size={22} strokeWidth={2.2} />
          <div>
            <p>Account</p>
            <h2>설정</h2>
          </div>
        </div>

        {isTemporaryAdmin ? (
          <div className="settings-card">
            <div className="settings-card-heading">
              <UserRound aria-hidden="true" size={19} strokeWidth={2.2} />
              <div>
                <strong>임시 관리자 로그인</strong>
                <span>Google 로그인 사용자가 아니어서 결제 설정은 비활성화됩니다.</span>
              </div>
            </div>
            <div className="settings-disabled-actions">
              <button type="button" disabled>
                프리미엄 설정
              </button>
              <button type="button" disabled>
                1,000 코인 충전
              </button>
            </div>
            <button
              type="button"
              className="settings-logout-button"
              onClick={onSignOut}
            >
              <LogOut aria-hidden="true" size={16} strokeWidth={2.2} />
              로그아웃
            </button>
          </div>
        ) : (
          <>
            {userProfileState.isLoading && !userProfileState.profile && (
              <div className="detail-state-card">
                <LoaderCircle
                  aria-hidden="true"
                  className="spinning-icon"
                  size={24}
                  strokeWidth={2.2}
                />
                <strong>계정 정보를 불러오는 중입니다</strong>
                <p>로그인된 이메일 기준으로 설정을 확인하고 있어요.</p>
              </div>
            )}

            {userProfileState.errorMessage && !userProfileState.profile && (
              <div className="detail-state-card detail-state-error">
                <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
                <strong>계정 정보를 불러오지 못했어요</strong>
                <p>{userProfileState.errorMessage}</p>
                <button
                  type="button"
                  className="detail-secondary-button"
                  onClick={onRetryLoadProfile}
                >
                  <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
                  다시 시도
                </button>
              </div>
            )}

            {userProfileState.profile && (
              <>
                <div className="settings-card">
                  <div className="settings-card-heading">
                    <UserRound aria-hidden="true" size={19} strokeWidth={2.2} />
                    <div>
                      <strong>{userProfileState.profile.email}</strong>
                      <span>
                        {userProfileState.profile.premium === 1
                          ? '프리미엄 사용자'
                          : '일반 사용자'}
                      </span>
                    </div>
                  </div>

                  <div className="settings-stat-grid">
                    <div>
                      <span>Coin</span>
                      <strong>{userProfileState.profile.coin.toLocaleString()}</strong>
                    </div>
                    <div>
                      <span>Free</span>
                      <strong>{userProfileState.profile.freecount}</strong>
                    </div>
                    <div>
                      <span>Premium</span>
                      <strong>{userProfileState.profile.premiumcount}</strong>
                    </div>
                  </div>
                </div>

                <div className="settings-card">
                  <div className="settings-card-heading">
                    <Crown aria-hidden="true" size={19} strokeWidth={2.2} />
                    <div>
                      <strong>프리미엄</strong>
                      <span>현재 계정의 premium 값을 1 또는 0으로 저장합니다.</span>
                    </div>
                  </div>
                  <button
                    type="button"
                    className="settings-primary-button"
                    disabled={userProfileState.isSaving}
                    onClick={onTogglePremium}
                  >
                    {userProfileState.profile.premium === 1 ? '프리미엄 해제' : '프리미엄 설정'}
                  </button>
                </div>

                <div className="settings-card">
                  <div className="settings-card-heading">
                    <Coins aria-hidden="true" size={19} strokeWidth={2.2} />
                    <div>
                      <strong>코인 충전</strong>
                      <span>테스트용 충전 버튼입니다.</span>
                    </div>
                  </div>
                  <div className="settings-coin-buttons">
                    {[1000, 2000, 3000].map((amount) => (
                      <button
                        type="button"
                        key={amount}
                        disabled={userProfileState.isSaving}
                        onClick={() => onChargeCoins(amount)}
                      >
                        {amount.toLocaleString()}
                      </button>
                    ))}
                  </div>
                </div>

                {userProfileState.errorMessage && (
                  <p className="settings-error-message">{userProfileState.errorMessage}</p>
                )}
              </>
            )}

            {!userProfileState.isLoading &&
              !userProfileState.profile &&
              !userProfileState.errorMessage && (
                <div className="bookmark-empty">
                  Google 로그인 정보를 확인할 수 없습니다
                </div>
              )}

            <button
              type="button"
              className="settings-logout-button"
              onClick={onSignOut}
            >
              <LogOut aria-hidden="true" size={16} strokeWidth={2.2} />
              로그아웃
            </button>
          </>
        )}
      </section>
    </aside>
  )
}
