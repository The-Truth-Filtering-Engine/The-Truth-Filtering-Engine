import { AlertCircle, Clock, LoaderCircle, RefreshCw, X } from 'lucide-react'
import { RestaurantThumb } from '../RestaurantThumb'
import { type RecentAnalysisItem } from '../../lib/restaurant'
import { type RecentAnalyses } from '../../api/user'

type RecentAnalysesState = {
  data: RecentAnalyses | null
  isLoading: boolean
  errorMessage: string
  hasLoaded: boolean
}

type Props = {
  recentAnalysesState: RecentAnalysesState
  isTemporaryAdmin: boolean
  authSessionExists: boolean
  onClose: () => void
  onFocusItem: (item: RecentAnalysisItem) => void
  onRetry: () => void
}

export function RecentPanel({
  recentAnalysesState,
  isTemporaryAdmin,
  authSessionExists,
  onClose,
  onFocusItem,
  onRetry,
}: Props) {
  const freeItems = recentAnalysesState.data?.freeItems ?? []
  const expiredItems = recentAnalysesState.data?.expiredItems ?? []
  const hasItems = freeItems.length > 0 || expiredItems.length > 0

  return (
    <aside className="restaurant-panel bookmark-panel recent-panel" aria-label="최근분석">
      <button
        type="button"
        className="panel-close-button"
        aria-label="최근분석 닫기"
        onClick={onClose}
      >
        <X aria-hidden="true" size={19} strokeWidth={2.2} />
      </button>

      <section className="bookmark-panel-body">
        <div className="bookmark-panel-header recent-panel-header">
          <Clock aria-hidden="true" size={22} strokeWidth={2.2} />
          <div>
            <p>Recent Analysis</p>
            <h2>최근분석</h2>
          </div>
        </div>

        {isTemporaryAdmin || !authSessionExists ? (
          <div className="bookmark-empty">
            Google 로그인 후 최근분석을 확인할 수 있습니다
          </div>
        ) : (
          <>
            {recentAnalysesState.isLoading && !recentAnalysesState.data && (
              <div className="detail-state-card">
                <LoaderCircle
                  aria-hidden="true"
                  className="spinning-icon"
                  size={24}
                  strokeWidth={2.2}
                />
                <strong>최근분석을 불러오는 중입니다</strong>
                <p>무료 분석 기간인 가게를 확인하고 있어요.</p>
              </div>
            )}

            {recentAnalysesState.errorMessage && (
              <div className="detail-state-card detail-state-error">
                <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
                <strong>최근분석을 불러오지 못했어요</strong>
                <p>{recentAnalysesState.errorMessage}</p>
                <button
                  type="button"
                  className="detail-secondary-button"
                  onClick={onRetry}
                >
                  <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
                  다시 시도
                </button>
              </div>
            )}

            {!recentAnalysesState.isLoading &&
              !recentAnalysesState.errorMessage &&
              recentAnalysesState.hasLoaded &&
              !hasItems && (
                <div className="bookmark-empty">아직 분석한 가게가 없습니다</div>
              )}

            {hasItems && (
              <div className="recent-analysis-groups">
                <section className="recent-analysis-section">
                  <div className="recent-section-heading">
                    <strong>무료 분석 가능</strong>
                    <span>{freeItems.length}개</span>
                  </div>
                  {freeItems.length === 0 ? (
                    <div className="recent-section-empty">무료 기간인 가게가 없습니다</div>
                  ) : (
                    <ul className="bookmark-list recent-analysis-list">
                      {freeItems.map((item) => (
                        <li key={`free-${item.storeId}`}>
                          <button
                            type="button"
                            className="bookmark-list-item recent-analysis-item"
                            onClick={() => onFocusItem(item)}
                          >
                            <RestaurantThumb
                              restaurant={item.restaurant}
                              className="bookmark-thumb"
                            />
                            <span className="bookmark-copy">
                              <strong>{item.restaurant.name}</strong>
                              <small>
                                {item.restaurant.category} ·{' '}
                                {item.restaurant.address || '주소 정보 없음'}
                              </small>
                              <em>
                                {item.analyzedDate} · 무료-{item.remainingFreeDays}일 남음
                              </em>
                            </span>
                          </button>
                        </li>
                      ))}
                    </ul>
                  )}
                </section>

                <section className="recent-analysis-section">
                  <div className="recent-section-heading">
                    <strong>지난 검색</strong>
                    <span>{expiredItems.length}개</span>
                  </div>
                  {expiredItems.length === 0 ? (
                    <div className="recent-section-empty">지난 검색 가게가 없습니다</div>
                  ) : (
                    <ul className="bookmark-list recent-analysis-list">
                      {expiredItems.map((item) => (
                        <li key={`expired-${item.storeId}`}>
                          <button
                            type="button"
                            className="bookmark-list-item recent-analysis-item"
                            onClick={() => onFocusItem(item)}
                          >
                            <RestaurantThumb
                              restaurant={item.restaurant}
                              className="bookmark-thumb"
                            />
                            <span className="bookmark-copy">
                              <strong>{item.restaurant.name}</strong>
                              <small>
                                {item.restaurant.category} ·{' '}
                                {item.restaurant.address || '주소 정보 없음'}
                              </small>
                              <em>
                                {item.analyzedDate}
                                {item.daysElapsed !== null ? ` · ${item.daysElapsed}일 전` : ''}
                              </em>
                            </span>
                          </button>
                        </li>
                      ))}
                    </ul>
                  )}
                </section>
              </div>
            )}
          </>
        )}
      </section>
    </aside>
  )
}
