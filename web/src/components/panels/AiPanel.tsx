import { AlertCircle, ExternalLink, LoaderCircle, MapPin, RefreshCw, Sparkles, X } from 'lucide-react'
import { formatAdScore } from '../../lib/format'
import { aiRecommendToRestaurant, type AiRecommendItem } from '../../lib/restaurant'

export type AiRegionScope = 'dong' | 'gu' | 'si'

const AI_REGION_SCOPE_LABELS: Record<AiRegionScope, string> = {
  si: '시',
  gu: '구',
  dong: '동',
}

const AI_REGION_SCOPE_OPTIONS: AiRegionScope[] = ['si', 'gu', 'dong']

export type AiRecommendState = {
  items: AiRecommendItem[]
  page: number
  hasNext: boolean
  isLoading: boolean
  errorMessage: string
  hasLoaded: boolean
  regionLabel: string
  currentRegionLabel: string
  currentRegionSi: string
  currentRegionGu: string
  currentRegionDong: string
  isRegionFiltered: boolean
}

function aiRegionScopeLabel(
  regionScope: AiRegionScope,
  state: Pick<AiRecommendState, 'currentRegionSi' | 'currentRegionGu' | 'currentRegionDong'>,
) {
  if (regionScope === 'si') return state.currentRegionSi || AI_REGION_SCOPE_LABELS.si
  if (regionScope === 'gu') return state.currentRegionGu || AI_REGION_SCOPE_LABELS.gu
  return state.currentRegionDong || AI_REGION_SCOPE_LABELS.dong
}

type Props = {
  aiRecommendState: AiRecommendState
  aiRegionScope: AiRegionScope
  currentPositionExists: boolean
  onClose: () => void
  onLoadPage: (page: number) => void
  onChangeRegionScope: (scope: AiRegionScope) => void
  onFocusItem: (item: AiRecommendItem) => void
}

export function AiPanel({
  aiRecommendState,
  aiRegionScope,
  currentPositionExists,
  onClose,
  onLoadPage,
  onChangeRegionScope,
  onFocusItem,
}: Props) {
  return (
    <aside className="restaurant-panel ai-panel" aria-label="AI 추천">
      <button
        type="button"
        className="panel-close-button"
        aria-label="AI 추천 닫기"
        onClick={onClose}
      >
        <X aria-hidden="true" size={19} strokeWidth={2.2} />
      </button>

      <section className="bookmark-panel-body">
        <div className="bookmark-panel-header">
          <Sparkles aria-hidden="true" size={22} strokeWidth={2.2} />
          <div>
            <p>{aiRecommendState.page} 페이지</p>
            <h2>AI 추천</h2>
          </div>
        </div>
        <p className="ai-panel-description">
          가게별로 광고 가능성이 낮게 감지된 리뷰입니다.
        </p>
        {aiRecommendState.currentRegionLabel && (
          <div className="ai-current-region" aria-label="현재 위치 행정구역">
            <span>현재 위치</span>
            <strong>{aiRecommendState.currentRegionLabel}</strong>
          </div>
        )}
        {aiRecommendState.currentRegionLabel ? (
          <div className="ai-region-tabs" role="tablist" aria-label="추천 지역 범위">
            {AI_REGION_SCOPE_OPTIONS.map((regionScope) => (
              <button
                type="button"
                key={regionScope}
                className={aiRegionScope === regionScope ? 'active' : ''}
                disabled={aiRecommendState.isLoading}
                onClick={() => onChangeRegionScope(regionScope)}
              >
                {aiRegionScopeLabel(regionScope, aiRecommendState)}
              </button>
            ))}
          </div>
        ) : (
          <p className="ai-region-status">
            {currentPositionExists
              ? '현재 위치를 확인하는 중입니다'
              : '현재 위치를 확인하면 지역별 추천이 적용됩니다'}
          </p>
        )}

        {aiRecommendState.isLoading && aiRecommendState.items.length === 0 && (
          <div className="detail-state-card">
            <LoaderCircle
              aria-hidden="true"
              className="spinning-icon"
              size={24}
              strokeWidth={2.2}
            />
            <strong>AI 추천을 불러오는 중입니다</strong>
            <p>광고 가능성이 낮은 리뷰를 찾고 있어요.</p>
          </div>
        )}

        {aiRecommendState.errorMessage && aiRecommendState.items.length === 0 && (
          <div className="detail-state-card detail-state-error">
            <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
            <strong>AI 추천 목록을 불러오지 못했어요</strong>
            <p>{aiRecommendState.errorMessage}</p>
            <button
              type="button"
              className="detail-secondary-button"
              onClick={() => onLoadPage(aiRecommendState.page)}
            >
              <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
              다시 시도
            </button>
          </div>
        )}

        {!aiRecommendState.isLoading &&
          !aiRecommendState.errorMessage &&
          aiRecommendState.items.length === 0 && (
            <div className="bookmark-empty">표시할 추천 데이터가 없습니다</div>
          )}

        {aiRecommendState.items.length > 0 && (
          <>
            <ul className="ai-recommend-list">
              {aiRecommendState.items.map((item) => {
                const restaurant = aiRecommendToRestaurant(item)
                const placeName = item.placeName || item.name || '이름 없는 장소'

                return (
                  <li key={item.id}>
                    <article className="ai-recommend-card">
                      <div className="ai-card-heading">
                        <strong>{placeName}</strong>
                        <span>광고 가능성 {formatAdScore(item.adScore)}</span>
                      </div>
                      <h3>{item.reviewTitle || '제목 없는 리뷰'}</h3>
                      {item.reviewDescription && <p>{item.reviewDescription}</p>}
                      <small>
                        {[item.bloggerName, item.postDate].filter(Boolean).join(' · ') ||
                          '블로그 리뷰'}
                      </small>
                      <div className="ai-card-actions">
                        <button
                          type="button"
                          disabled={!restaurant}
                          onClick={() => onFocusItem(item)}
                        >
                          <MapPin aria-hidden="true" size={15} strokeWidth={2.2} />
                          위치 보기
                        </button>
                        <button
                          type="button"
                          disabled={!item.reviewUrl}
                          onClick={() => {
                            if (item.reviewUrl) {
                              window.open(item.reviewUrl, '_blank', 'noopener,noreferrer')
                            }
                          }}
                        >
                          <ExternalLink aria-hidden="true" size={15} strokeWidth={2.2} />
                          리뷰 열기
                        </button>
                      </div>
                    </article>
                  </li>
                )
              })}
            </ul>

            <div className="ai-pagination">
              <button
                type="button"
                disabled={aiRecommendState.page <= 1 || aiRecommendState.isLoading}
                onClick={() => onLoadPage(aiRecommendState.page - 1)}
              >
                이전 10개
              </button>
              <button
                type="button"
                disabled={!aiRecommendState.hasNext || aiRecommendState.isLoading}
                onClick={() => onLoadPage(aiRecommendState.page + 1)}
              >
                {aiRecommendState.isLoading ? '불러오는 중' : '다음 10개'}
              </button>
            </div>
          </>
        )}
      </section>
    </aside>
  )
}
