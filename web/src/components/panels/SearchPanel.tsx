import { AlertCircle, LoaderCircle, RefreshCw, Search } from 'lucide-react'
import { type FormEvent } from 'react'
import { RestaurantThumb } from '../RestaurantThumb'
import { formatDistance } from '../../lib/format'
import { type Restaurant } from '../../lib/restaurant'

type SearchState = 'idle' | 'loading' | 'loaded' | 'error'

type Props = {
  searchInput: string
  searchQuery: string
  searchResults: Restaurant[]
  searchState: SearchState
  searchErrorMessage: string
  onSearchInputChange: (value: string) => void
  onSearchSubmit: (event?: FormEvent<HTMLFormElement>) => void
  onSelectResult: (restaurant: Restaurant) => void
}

export function SearchPanel({
  searchInput,
  searchQuery,
  searchResults,
  searchState,
  searchErrorMessage,
  onSearchInputChange,
  onSearchSubmit,
  onSelectResult,
}: Props) {
  return (
    <aside className="restaurant-panel search-panel" aria-label="장소 검색">
      <section className="search-panel-body">
        <div className="search-panel-header">
          <Search aria-hidden="true" size={22} strokeWidth={2.2} />
          <div>
            <p>Search</p>
            <h2>장소 검색</h2>
          </div>
        </div>

        <form className="map-search-form" onSubmit={onSearchSubmit}>
          <label className="map-search-field">
            <Search aria-hidden="true" size={18} strokeWidth={2.2} />
            <input
              type="search"
              value={searchInput}
              placeholder="음식점 또는 메뉴를 검색"
              onChange={(event) => onSearchInputChange(event.target.value)}
            />
          </label>
          <button
            type="submit"
            className="map-search-submit"
            aria-label="검색"
            disabled={searchState === 'loading'}
          >
            {searchState === 'loading' ? (
              <LoaderCircle
                aria-hidden="true"
                className="spinning-icon"
                size={18}
                strokeWidth={2.2}
              />
            ) : (
              <Search aria-hidden="true" size={18} strokeWidth={2.2} />
            )}
          </button>
        </form>

        {searchState === 'idle' && (
          <div className="search-empty-state">
            <Search aria-hidden="true" size={26} strokeWidth={2.1} />
            <strong>검색어를 입력하세요</strong>
          </div>
        )}

        {searchState === 'loading' && (
          <div className="detail-state-card search-state-card">
            <LoaderCircle
              aria-hidden="true"
              className="spinning-icon"
              size={24}
              strokeWidth={2.2}
            />
            <strong>검색 결과를 불러오는 중입니다</strong>
          </div>
        )}

        {searchState === 'error' && (
          <div className="detail-state-card detail-state-error search-state-card">
            <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
            <strong>검색 결과를 불러오지 못했어요</strong>
            <p>{searchErrorMessage}</p>
            <button
              type="button"
              className="detail-secondary-button"
              onClick={() => onSearchSubmit()}
            >
              <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
              다시 시도
            </button>
          </div>
        )}

        {searchState === 'loaded' && searchResults.length === 0 && (
          <div className="bookmark-empty">"{searchQuery}" 검색 결과가 없습니다</div>
        )}

        {searchState === 'loaded' && searchResults.length > 0 && (
          <div className="search-results">
            <div className="search-results-summary">
              <strong>"{searchQuery}"</strong>
              <span>{searchResults.length}개 결과</span>
            </div>
            <ul className="search-result-list">
              {searchResults.map((restaurant) => (
                <li key={restaurant.id}>
                  <button
                    type="button"
                    className="search-result-card"
                    onClick={() => onSelectResult(restaurant)}
                  >
                    <RestaurantThumb
                      restaurant={restaurant}
                      className="bookmark-thumb search-result-thumb"
                    />
                    <span className="search-result-copy">
                      <strong>{restaurant.name}</strong>
                      <small>{restaurant.category}</small>
                      <span>
                        {restaurant.address || '주소 정보 없음'} ·{' '}
                        {formatDistance(restaurant.distance)}
                      </span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          </div>
        )}
      </section>
    </aside>
  )
}
