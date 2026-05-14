import {
  AlertCircle,
  ArrowLeft,
  Ban,
  Bookmark,
  BookmarkCheck,
  CheckCircle2,
  Clock,
  ExternalLink,
  Flag,
  Heart,
  Info,
  Link2Off,
  LoaderCircle,
  Megaphone,
  MoreHorizontal,
  Navigation,
  Phone,
  RefreshCw,
  Share2,
  X,
} from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { RestaurantThumb } from '../RestaurantThumb'
import { formatDistance } from '../../lib/format'
import { getRestaurantStoreId, type Restaurant } from '../../lib/restaurant'
import {
  REPORT_CATEGORIES,
  gradeLabel,
  type BlogReview,
  type DetailData,
  type ReportCategoryCode,
  REVIEW_PAGE_SIZE,
} from '../../api/reviews'
import { type DetailState } from '../../hooks/useDetail'
import {
  type ReviewLikeViewState,
  type ReviewReportSubmitResult,
  type ReviewReportViewState,
} from '../../hooks/useReviewActivity'

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
  reviewActivityAvailable: boolean
  getReviewLikeState: (review: BlogReview) => ReviewLikeViewState
  getReviewReportState: (review: BlogReview) => ReviewReportViewState
  onToggleReviewHeart: (review: BlogReview) => void
  onSubmitReviewReport: (
    review: BlogReview,
    category: ReportCategoryCode,
    memo?: string,
  ) => Promise<ReviewReportSubmitResult>
  onHideReview: (reviewId: string) => void
  onOpenReviewSource: (review: BlogReview) => void
  onShowToast: (message: string) => void
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
  reviewActivityAvailable,
  getReviewLikeState,
  getReviewReportState,
  onToggleReviewHeart,
  onSubmitReviewReport,
  onHideReview,
  onOpenReviewSource,
  onShowToast,
}: Props) {
  const isBookmarked = bookmarkedStoreIds.includes(getRestaurantStoreId(restaurant))
  const [reportTarget, setReportTarget] = useState<BlogReview | null>(null)

  async function handleSubmitReviewReport(category: ReportCategoryCode, memo?: string) {
    if (!reportTarget) return

    const targetReview = reportTarget
    const result = await onSubmitReviewReport(targetReview, category, memo)
    if (result !== 'submitted') return

    setReportTarget(null)
    onHideReview(targetReview.reviewId)
    onShowToast('신고가 접수되어 리뷰를 숨겼습니다.')
  }

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
                        <ReviewCard
                          review={review}
                          reviewActivityAvailable={reviewActivityAvailable}
                          likeState={getReviewLikeState(review)}
                          reportState={getReviewReportState(review)}
                          onToggleReviewHeart={onToggleReviewHeart}
                          onOpenReportDialog={setReportTarget}
                          onOpenReviewSource={onOpenReviewSource}
                        />
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
      {reportTarget && (
        <ReviewReportDialog
          review={reportTarget}
          onClose={() => setReportTarget(null)}
          onSubmit={handleSubmitReviewReport}
        />
      )}
    </aside>
  )
}

type ReviewCardProps = {
  review: BlogReview
  reviewActivityAvailable: boolean
  likeState: ReviewLikeViewState
  reportState: ReviewReportViewState
  onToggleReviewHeart: (review: BlogReview) => void
  onOpenReportDialog: (review: BlogReview) => void
  onOpenReviewSource: (review: BlogReview) => void
}

function ReviewCard({
  review,
  reviewActivityAvailable,
  likeState,
  reportState,
  onToggleReviewHeart,
  onOpenReportDialog,
  onOpenReviewSource,
}: ReviewCardProps) {
  return (
    <article className="review-card">
      <div className="review-card-topline">
        <span className={`review-grade ${review.grade}`}>
          {gradeLabel(review.grade)}
        </span>
        <div className="review-card-actions" aria-label="리뷰 액션">
          <button
            type="button"
            className={`review-heart-button ${likeState.isLiked ? 'active' : ''}`}
            disabled={!reviewActivityAvailable || likeState.isSaving}
            aria-label={likeState.isLiked ? '내 하트 해제' : '내 하트 추가'}
            onClick={() => onToggleReviewHeart(review)}
          >
            <Heart
              aria-hidden="true"
              size={15}
              strokeWidth={2.3}
              fill={likeState.isLiked ? 'currentColor' : 'none'}
            />
            <span>{likeState.likeCount}</span>
          </button>
          <button
            type="button"
            className={`review-report-button ${reportState.isReported ? 'active' : ''}`}
            disabled={!reviewActivityAvailable}
            aria-label={reportState.isReported ? '신고됨' : '리뷰 신고'}
            title={reportState.isReported ? '신고됨' : '리뷰 신고'}
            onClick={() => onOpenReportDialog(review)}
          >
            <Flag
              aria-hidden="true"
              size={15}
              strokeWidth={2.3}
              fill={reportState.isReported ? 'currentColor' : 'none'}
            />
          </button>
        </div>
      </div>
      <strong>{review.title}</strong>
      <p>{review.preview}</p>
      <small>
        {review.author}
        {review.date ? ` · ${review.date}` : ''}
      </small>
      {review.url && (
        <button
          type="button"
          className="review-open-button"
          onClick={() => onOpenReviewSource(review)}
        >
          <ExternalLink aria-hidden="true" size={14} strokeWidth={2.2} />
          원문 보기
        </button>
      )}
    </article>
  )
}

type ReviewReportDialogProps = {
  review: BlogReview
  onClose: () => void
  onSubmit: (category: ReportCategoryCode, memo?: string) => Promise<void>
}

function ReviewReportDialog({ review, onClose, onSubmit }: ReviewReportDialogProps) {
  const [selectedCategory, setSelectedCategory] = useState<ReportCategoryCode | null>(null)
  const [memo, setMemo] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!selectedCategory || isSubmitting) return

    setIsSubmitting(true)
    try {
      await onSubmit(selectedCategory, selectedCategory === 4 ? memo : undefined)
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="review-report-backdrop" role="presentation">
      <form
        className="review-report-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="review-report-title"
        onSubmit={handleSubmit}
      >
        <header className="review-report-header">
          <span className="review-report-header-icon" aria-hidden="true">
            <Flag size={17} strokeWidth={2.3} />
          </span>
          <div>
            <h2 id="review-report-title">리뷰 신고</h2>
            <p>{review.title}</p>
          </div>
          <button type="button" className="review-report-close" aria-label="닫기" onClick={onClose}>
            <X aria-hidden="true" size={18} strokeWidth={2.3} />
          </button>
        </header>

        <div className="review-report-options" role="radiogroup" aria-label="신고 사유">
          {REPORT_CATEGORIES.map((category) => {
            const isSelected = selectedCategory === category.code
            return (
              <button
                key={category.code}
                type="button"
                className={`review-report-option ${isSelected ? 'active' : ''}`}
                role="radio"
                aria-checked={isSelected}
                onClick={() => setSelectedCategory(category.code)}
              >
                <ReportCategoryIcon code={category.code} />
                <span>{category.label}</span>
                {isSelected && <CheckCircle2 aria-hidden="true" size={17} strokeWidth={2.3} />}
              </button>
            )
          })}
        </div>

        {selectedCategory === 4 && (
          <label className="review-report-memo">
            <span>상세 사유</span>
            <textarea
              value={memo}
              maxLength={200}
              rows={3}
              placeholder="신고 사유를 직접 입력해 주세요."
              onChange={(event) => setMemo(event.target.value)}
            />
          </label>
        )}

        <button
          type="submit"
          className="review-report-submit"
          disabled={!selectedCategory || isSubmitting}
        >
          {isSubmitting ? (
            <LoaderCircle aria-hidden="true" className="spinning-icon" size={16} strokeWidth={2.3} />
          ) : (
            <Flag aria-hidden="true" size={16} strokeWidth={2.3} />
          )}
          <span>{isSubmitting ? '접수 중' : '신고하기'}</span>
        </button>
      </form>
    </div>
  )
}

function ReportCategoryIcon({ code }: { code: ReportCategoryCode }) {
  const iconProps = { 'aria-hidden': true, size: 17, strokeWidth: 2.2 }

  if (code === 1) return <Megaphone {...iconProps} />
  if (code === 2) return <Link2Off {...iconProps} />
  if (code === 3) return <Ban {...iconProps} />
  return <MoreHorizontal {...iconProps} />
}
