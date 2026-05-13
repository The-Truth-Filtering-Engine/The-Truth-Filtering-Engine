REVIEW_BATCH_SIZE = 100
MAX_REVIEW_RESULTS = 100
NAVER_MAX_START = 1000
STREAM_BATCH_SIZE = 32

def clamp_review_limit(value: int, default: int = REVIEW_BATCH_SIZE) -> int:
    if value <= 0:
        return default
    return min(value, REVIEW_BATCH_SIZE)


def clamp_max_results(value: int, default: int = MAX_REVIEW_RESULTS) -> int:
    if value <= 0:
        return default
    return min(value, MAX_REVIEW_RESULTS)


def normalize_naver_start(value: int) -> int:
    if value < 1:
        return 1
    batch_index = (value - 1) // REVIEW_BATCH_SIZE
    normalized = batch_index * REVIEW_BATCH_SIZE + 1
    return min(normalized, MAX_REVIEW_RESULTS - REVIEW_BATCH_SIZE + 1, NAVER_MAX_START)
