import {
  AlertCircle,
  ArrowLeft,
  Bookmark,
  BookmarkCheck,
  Clock,
  Info,
  LoaderCircle,
  MapPin,
  Navigation,
  Phone,
  RefreshCw,
  Share2,
  X,
} from 'lucide-react'
import { RestaurantThumb } from '../RestaurantThumb'
import { formatDistance } from '../../lib/format'
import { getRestaurantStoreId, type Restaurant } from '../../lib/restaurant'
import { gradeLabel, type BlogReview, type DetailData, REVIEW_PAGE_SIZE } from '../../api/reviews'
import { type DetailState } from '../../hooks/useDetail'

type Props = {
  restaurant: Restaurant
  bookmarkedStoreIds: string[]
  detailState: DetailState
  detailData: DetailData | null
  detailErrorMessage: string
  reviewSort: 'real' | 'latest'
  reviewPage: number
  reviewTotalPages: number
  visibleDetailReviews: BlogReview[]
  showReviewPageSkeleton: boolean
  isReviewBatchLoading: boolean
  onBack: () => void
  onClose: () => void
  onCall: (restaurant: Restaurant) => void
  onToggleBookmark: (restaurant: Restaurant) => void
  onRoute: (restaurant: Restaurant) => void
  onShare: (restaurant: Restaurant) => void
  onRefresh: (restaurant: Restaurant) => void
  onChangeReviewSort: (sort: 'real' | 'latest') => void
  onChangeReviewPage: (page: number) => void
}

export function DetailPanel({
  restaurant,
  bookmarkedStoreIds,
  detailState,
  detailData,
  detailErrorMessage,
  reviewSort,
  reviewPage,
  reviewTotalPages,
  visibleDetailReviews,
  showReviewPageSkeleton,
  isReviewBatchLoading,
  onBack,
  onClose,
  onCall,
  onToggleBookmark,
  onRoute,
  onShare,
  onRefresh,
  onChangeReviewSort,
  onChangeReviewPage,
}: Props) {
  const isBookmarked = bookmarkedStoreIds.includes(getRestaurantStoreId(restaurant))

  return (
    <aside className="restaurant-panel detail-panel" aria-label="가게 상세 정보">
      <div className="detail-panel-topbar">
        <button
          type="button"
          className="panel-icon-button"
          aria-label="가게 정보로 돌아가기"
          onClick={onBack}
        >
          <ArrowLeft aria-hidden="true" size={19} strokeWidth={2.2} />
        </button>
        <strong>{restaurant.name}</strong>
        <button
          type="button"
          className="panel-icon-button"
          aria-label="상세 정보 닫기"
          onClick={onClose}
        >
          <X aria-hidden="true" size={19} strokeWidth={2.2} />
        </button>
      </div>

      <section className="detail-panel-body">
        <div className="detail-restaurant-card">
          <RestaurantThumb
            restaurant={restaurant}
            className="bookmark-thumb detail-thumb"
          />
          <div>
            <p>{restaurant.category}</p>
            <h2>{restaurant.name}</h2>
            <small>
              {restaurant.address || '주소 정보 없음'} ·{' '}
              {formatDistance(restaurant.distance)}
            </small>
          </div>
        </div>

        <div className="restaurant-actions detail-actions" aria-label="가게 액션">
          <button type="button" onClick={() => onCall(restaurant)}>
            <Phone aria-hidden="true" size={20} strokeWidth={2.1} />
            <span>Call</span>
          </button>
          <button type="button" onClick={() => onToggleBookmark(restaurant)}>
            {isBookmarked ? (
              <BookmarkCheck aria-hidden="true" size={20} strokeWidth={2.1} />
            ) : (
              <Bookmark aria-hidden="true" size={20} strokeWidth={2.1} />
            )}
            <span>Save</span>
          </button>
          <button type="button" onClick={() => onRoute(restaurant)}>
            <Navigation aria-hidden="true" size={20} strokeWidth={2.1} />
            <span>Route</span>
          </button>
          <button type="button" onClick={() => onShare(restaurant)}>
            <Share2 aria-hidden="true" size={20} strokeWidth={2.1} />
            <span>Share</span>
          </button>
        </div>

        {(detailState === 'loading' || detailState === 'analyzing') && (
          <div className="detail-state-card">
            <LoaderCircle aria-hidden="true" className="spinning-icon" size={24} strokeWidth={2.2} />
            <strong>
              {detailState === 'loading'
                ? '저장된 리뷰를 확인하는 중입니다'
                : '새 리뷰를 수집하고 분석하는 중입니다'}
            </strong>
            <p>조금만 기다려 주세요. 지도는 그대로 사용할 수 있습니다.</p>
          </div>
        )}

        {detailState === 'noData' && (
          <div className="detail-state-card">
            <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
            <strong>아직 분석된 리뷰가 없습니다</strong>
            <p>새 분석을 다시 요청해 볼 수 있습니다.</p>
            <button
              type="button"
              className="detail-secondary-button"
              onClick={() => onRefresh(restaurant)}
            >
              <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
              다시 분석
            </button>
          </div>
        )}

        {detailState === 'error' && (
          <div className="detail-state-card detail-state-error">
            <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
            <strong>상세 정보를 불러오지 못했습니다</strong>
            <p>{detailErrorMessage}</p>
            <button
              type="button"
              className="detail-secondary-button"
              onClick={() => onRefresh(restaurant)}
            >
              <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
              다시 시도
            </button>
          </div>
        )}

        {detailState === 'loaded' && detailData && (
          <>
            <section className="detail-section">
              <div className="detail-section-heading">
                <Info aria-hidden="true" size={17} strokeWidth={2.2} />
                <h3>리뷰 키워드</h3>
              </div>
              {detailData.keywords.length > 0 ? (
                <div className="keyword-cloud">
                  {detailData.keywords.map((keyword) => (
                    <span
                      key={keyword.word}
                      style={{ fontSize: `${Math.min(18, 12 + keyword.count * 2)}px` }}
                    >
                      {keyword.word}
                    </span>
                  ))}
                </div>
              ) : (
                <p className="detail-muted">표시할 키워드가 없습니다.</p>
              )}
            </section>

            <section className="detail-section review-section">
              <div className="detail-section-heading">
                <Clock aria-hidden="true" size={17} strokeWidth={2.2} />
                <h3>블로그 리뷰</h3>
              </div>
              <div className="review-tabs" role="tablist" aria-label="리뷰 정렬">
                <button
                  type="button"
                  className={reviewSort === 'real' ? 'active' : ''}
                  onClick={() => onChangeReviewSort('real')}
                >
                  진성순
                </button>
                <button
                  type="button"
                  className={reviewSort === 'latest' ? 'active' : ''}
                  onClick={() => onChangeReviewSort('latest')}
                >
                  최신순
                </button>
              </div>
              <ul className="review-list">
                {showReviewPageSkeleton
                  ? Array.from({ length: REVIEW_PAGE_SIZE }, (_, index) => (
                      <li key={`review-skeleton-${index}`}>
                        <article className="review-card review-card-skeleton" aria-hidden="true">
                          <span className="skeleton-pill" />
                          <span className="skeleton-line skeleton-title" />
                          <span className="skeleton-line" />
                          <span className="skeleton-line skeleton-short" />
                          <span className="skeleton-line skeleton-meta" />
                        </article>
                      </li>
                    ))
                  : visibleDetailReviews.map((review) => (
                      <li key={`${review.id}-${review.url || review.title}`}>
                        {review.url ? (
                          <a
                            className="review-card"
                            href={review.url}
                            target="_blank"
                            rel="noopener noreferrer"
                            aria-label={`${review.title} 원문 열기`}
                          >
                            <span className={`review-grade ${review.grade}`}>
                              {gradeLabel(review.grade)}
                            </span>
                            <strong>{review.title}</strong>
                            <p>{review.preview}</p>
                            <small>
                              {review.author}
                              {review.date ? ` · ${review.date}` : ''}
                            </small>
                          </a>
                        ) : (
                          <article className="review-card">
                            <span className={`review-grade ${review.grade}`}>
                              {gradeLabel(review.grade)}
                            </span>
                            <strong>{review.title}</strong>
                            <p>{review.preview}</p>
                            <small>
                              {review.author}
                              {review.date ? ` · ${review.date}` : ''}
                            </small>
                          </article>
                        )}
                      </li>
                    ))}
              </ul>
              {reviewTotalPages > 1 && (
                <div className="review-pagination">
                  <button
                    type="button"
                    disabled={reviewPage <= 0 || isReviewBatchLoading}
                    onClick={() => onChangeReviewPage(reviewPage - 1)}
                  >
                    이전
                  </button>
                  <span>
                    {reviewPage + 1} / {reviewTotalPages}
                  </span>
                  <button
                    type="button"
                    disabled={reviewPage >= reviewTotalPages - 1 || isReviewBatchLoading}
                    onClick={() => onChangeReviewPage(reviewPage + 1)}
                  >
                    다음
                  </button>
                </div>
              )}
            </section>
          </>
        )}
      </section>
    </aside>
  )
}
