import {
  AlertCircle,
  ArrowLeft,
  Coins,
  Crown,
  ExternalLink,
  Heart,
  History,
  LoaderCircle,
  LogOut,
  RefreshCw,
  Settings,
  Trash2,
  UserRound,
  X,
} from 'lucide-react'
import { useEffect, useState, type ReactNode } from 'react'
import { type BlogReview } from '../../api/reviews'
import { type UserProfile } from '../../api/user'
import {
  type LikedReviewItem,
  type RecentReviewItem,
  type ReviewCollectionState,
} from '../../hooks/useReviewActivity'

type UserProfileState = {
  profile: UserProfile | null
  isLoading: boolean
  isSaving: boolean
  errorMessage: string
  hasLoaded: boolean
}

type SettingsView = 'main' | 'liked' | 'recent'

type Props = {
  userProfileState: UserProfileState
  isTemporaryAdmin: boolean
  onClose: () => void
  onTogglePremium: () => void
  onChargeCoins: (amount: number) => void
  onSignOut: () => void
  onRetryLoadProfile: () => void
  reviewActivityAvailable: boolean
  likedReviewsState: ReviewCollectionState<LikedReviewItem>
  recentReviewsState: ReviewCollectionState<RecentReviewItem>
  onLoadLikedReviews: () => void
  onLoadRecentReviews: () => void
  onOpenLikedReview: (review: BlogReview) => void
  onOpenRecentReview: (review: RecentReviewItem) => void
  onRemoveLikedReview: (review: LikedReviewItem) => Promise<void>
  onRemoveRecentReview: (reviewId: string) => Promise<void>
  onClearRecentReviews: () => Promise<void>
}

export function SettingsPanel({
  userProfileState,
  isTemporaryAdmin,
  onClose,
  onTogglePremium,
  onChargeCoins,
  onSignOut,
  onRetryLoadProfile,
  reviewActivityAvailable,
  likedReviewsState,
  recentReviewsState,
  onLoadLikedReviews,
  onLoadRecentReviews,
  onOpenLikedReview,
  onOpenRecentReview,
  onRemoveLikedReview,
  onRemoveRecentReview,
  onClearRecentReviews,
}: Props) {
  const [view, setView] = useState<SettingsView>('main')
  const [reviewActionError, setReviewActionError] = useState('')

  function openLikedReviews() {
    setReviewActionError('')
    setView('liked')
  }

  function openRecentReviews() {
    setReviewActionError('')
    setView('recent')
  }

  useEffect(() => {
    if (view === 'liked' && !likedReviewsState.hasLoaded && !likedReviewsState.isLoading) {
      onLoadLikedReviews()
    }
    if (view === 'recent' && !recentReviewsState.hasLoaded && !recentReviewsState.isLoading) {
      onLoadRecentReviews()
    }
  }, [
    likedReviewsState.hasLoaded,
    likedReviewsState.isLoading,
    onLoadLikedReviews,
    onLoadRecentReviews,
    recentReviewsState.hasLoaded,
    recentReviewsState.isLoading,
    view,
  ])

  async function runReviewAction(action: () => Promise<void>, fallbackMessage: string) {
    setReviewActionError('')
    try {
      await action()
    } catch (error) {
      setReviewActionError(error instanceof Error ? error.message : fallbackMessage)
    }
  }

  const title = view === 'liked' ? '내 하트' : view === 'recent' ? '최근 기록' : '설정'
  const eyebrow = view === 'main' ? 'Account' : 'Reviews'

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
          {view === 'main' ? (
            <Settings aria-hidden="true" size={22} strokeWidth={2.2} />
          ) : (
            <button
              type="button"
              className="settings-back-button"
              aria-label="설정으로 돌아가기"
              onClick={() => {
                setReviewActionError('')
                setView('main')
              }}
            >
              <ArrowLeft aria-hidden="true" size={18} strokeWidth={2.2} />
            </button>
          )}
          <div>
            <p>{eyebrow}</p>
            <h2>{title}</h2>
          </div>
        </div>

        {view === 'liked' ? (
          <LikedReviewsView
            state={likedReviewsState}
            actionError={reviewActionError}
            onRetry={onLoadLikedReviews}
            onOpen={onOpenLikedReview}
            onRemove={(review) =>
              runReviewAction(
                () => onRemoveLikedReview(review),
                '내 하트를 해제하지 못했습니다',
              )
            }
          />
        ) : view === 'recent' ? (
          <RecentReviewsView
            state={recentReviewsState}
            actionError={reviewActionError}
            onRetry={onLoadRecentReviews}
            onOpen={onOpenRecentReview}
            onRemove={(reviewId) =>
              runReviewAction(
                () => onRemoveRecentReview(reviewId),
                '최근 기록을 삭제하지 못했습니다',
              )
            }
            onClear={() =>
              runReviewAction(
                onClearRecentReviews,
                '최근 기록을 모두 삭제하지 못했습니다',
              )
            }
          />
        ) : isTemporaryAdmin ? (
          <TemporaryAdminSettings onSignOut={onSignOut} />
        ) : (
          <MainSettingsView
            userProfileState={userProfileState}
            reviewActivityAvailable={reviewActivityAvailable}
            onTogglePremium={onTogglePremium}
            onChargeCoins={onChargeCoins}
            onSignOut={onSignOut}
            onRetryLoadProfile={onRetryLoadProfile}
            onOpenLikedReviews={openLikedReviews}
            onOpenRecentReviews={openRecentReviews}
          />
        )}
      </section>
    </aside>
  )
}

function TemporaryAdminSettings({ onSignOut }: { onSignOut: () => void }) {
  return (
    <div className="settings-card">
      <div className="settings-card-heading">
        <UserRound aria-hidden="true" size={19} strokeWidth={2.2} />
        <div>
          <strong>임시 관리자 로그인</strong>
          <span>Google 로그인 사용자가 아니어서 계정 리뷰 기능은 비활성화됩니다.</span>
        </div>
      </div>
      <div className="settings-disabled-actions">
        <button type="button" disabled>
          프리미엄 설정
        </button>
        <button type="button" disabled>
          내 하트
        </button>
        <button type="button" disabled>
          최근 기록
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
  )
}

type MainSettingsViewProps = {
  userProfileState: UserProfileState
  reviewActivityAvailable: boolean
  onTogglePremium: () => void
  onChargeCoins: (amount: number) => void
  onSignOut: () => void
  onRetryLoadProfile: () => void
  onOpenLikedReviews: () => void
  onOpenRecentReviews: () => void
}

function MainSettingsView({
  userProfileState,
  reviewActivityAvailable,
  onTogglePremium,
  onChargeCoins,
  onSignOut,
  onRetryLoadProfile,
  onOpenLikedReviews,
  onOpenRecentReviews,
}: MainSettingsViewProps) {
  return (
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
              <Heart aria-hidden="true" size={19} strokeWidth={2.2} />
              <div>
                <strong>리뷰</strong>
                <span>하트한 리뷰와 최근 열어본 리뷰를 확인합니다.</span>
              </div>
            </div>
            <div className="settings-review-buttons">
              <button
                type="button"
                disabled={!reviewActivityAvailable}
                onClick={onOpenLikedReviews}
              >
                <Heart aria-hidden="true" size={16} strokeWidth={2.2} />
                내 하트
              </button>
              <button
                type="button"
                disabled={!reviewActivityAvailable}
                onClick={onOpenRecentReviews}
              >
                <History aria-hidden="true" size={16} strokeWidth={2.2} />
                최근 기록
              </button>
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
  )
}

type LikedReviewsViewProps = {
  state: ReviewCollectionState<LikedReviewItem>
  actionError: string
  onRetry: () => void
  onOpen: (review: BlogReview) => void
  onRemove: (review: LikedReviewItem) => void
}

function LikedReviewsView({
  state,
  actionError,
  onRetry,
  onOpen,
  onRemove,
}: LikedReviewsViewProps) {
  if (state.isLoading || !state.hasLoaded) {
    return <SettingsLoadingMessage message="내 하트 목록을 불러오는 중입니다" />
  }

  if (state.errorMessage) {
    return (
      <SettingsErrorMessage message={state.errorMessage} onRetry={onRetry} />
    )
  }

  if (state.items.length === 0) {
    return (
      <SettingsEmptyMessage
        icon={<Heart aria-hidden="true" size={26} strokeWidth={2.2} />}
        message="하트를 누른 리뷰가 없습니다."
      />
    )
  }

  return (
    <>
      {actionError && <p className="settings-error-message">{actionError}</p>}
      <ul className="settings-review-list">
        {state.items.map((review) => (
          <li key={review.reviewId}>
            <ReviewListItem
              title={review.title}
              source={review.restaurantName}
              description={review.description || review.preview}
              leading={
                <button
                  type="button"
                  className="settings-review-icon-button danger"
                  aria-label="내 하트 해제"
                  onClick={() => onRemove(review)}
                >
                  <Heart aria-hidden="true" size={17} strokeWidth={2.2} fill="currentColor" />
                </button>
              }
              onOpen={() => onOpen(review)}
            />
          </li>
        ))}
      </ul>
    </>
  )
}

type RecentReviewsViewProps = {
  state: ReviewCollectionState<RecentReviewItem>
  actionError: string
  onRetry: () => void
  onOpen: (review: RecentReviewItem) => void
  onRemove: (reviewId: string) => void
  onClear: () => void
}

function RecentReviewsView({
  state,
  actionError,
  onRetry,
  onOpen,
  onRemove,
  onClear,
}: RecentReviewsViewProps) {
  if (state.isLoading || !state.hasLoaded) {
    return <SettingsLoadingMessage message="최근 기록을 불러오는 중입니다" />
  }

  if (state.errorMessage) {
    return (
      <SettingsErrorMessage message={state.errorMessage} onRetry={onRetry} />
    )
  }

  if (state.items.length === 0) {
    return (
      <SettingsEmptyMessage
        icon={<History aria-hidden="true" size={26} strokeWidth={2.2} />}
        message="최근 기록이 없습니다."
      />
    )
  }

  return (
    <>
      <button type="button" className="settings-clear-button" onClick={onClear}>
        <Trash2 aria-hidden="true" size={15} strokeWidth={2.2} />
        전체 삭제
      </button>
      {actionError && <p className="settings-error-message">{actionError}</p>}
      <ul className="settings-review-list">
        {state.items.map((review) => (
          <li key={review.reviewId}>
            <ReviewListItem
              title={review.title || '제목 없는 리뷰'}
              source={review.name}
              description={review.description}
              leading={
                <button
                  type="button"
                  className="settings-review-icon-button"
                  aria-label="최근 기록 삭제"
                  onClick={() => onRemove(review.reviewId)}
                >
                  <X aria-hidden="true" size={17} strokeWidth={2.2} />
                </button>
              }
              onOpen={() => onOpen(review)}
            />
          </li>
        ))}
      </ul>
    </>
  )
}

type ReviewListItemProps = {
  title: string
  source: string
  description: string
  leading: ReactNode
  onOpen: () => void
}

function ReviewListItem({
  title,
  source,
  description,
  leading,
  onOpen,
}: ReviewListItemProps) {
  return (
    <article className="settings-review-item">
      {leading}
      <button type="button" className="settings-review-content" onClick={onOpen}>
        <strong>{title || '제목 없는 리뷰'}</strong>
        {source && <span>{source}</span>}
        {description && <p>{description}</p>}
      </button>
      <button
        type="button"
        className="settings-review-icon-button"
        aria-label="원문 열기"
        onClick={onOpen}
      >
        <ExternalLink aria-hidden="true" size={16} strokeWidth={2.2} />
      </button>
    </article>
  )
}

function SettingsLoadingMessage({ message }: { message: string }) {
  return (
    <div className="detail-state-card">
      <LoaderCircle
        aria-hidden="true"
        className="spinning-icon"
        size={24}
        strokeWidth={2.2}
      />
      <strong>{message}</strong>
    </div>
  )
}

function SettingsErrorMessage({
  message,
  onRetry,
}: {
  message: string
  onRetry: () => void
}) {
  return (
    <div className="detail-state-card detail-state-error">
      <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
      <strong>목록을 불러오지 못했어요</strong>
      <p>{message}</p>
      <button
        type="button"
        className="detail-secondary-button"
        onClick={onRetry}
      >
        <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
        다시 시도
      </button>
    </div>
  )
}

function SettingsEmptyMessage({
  icon,
  message,
}: {
  icon: ReactNode
  message: string
}) {
  return (
    <div className="bookmark-empty settings-review-empty">
      {icon}
      <span>{message}</span>
    </div>
  )
}
