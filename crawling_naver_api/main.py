import json
import os
from search import get_blog_reviews

def get_save_path(restaurant_name):
    safe_name = restaurant_name.replace('/', '_').replace('\\', '_') \
                               .replace(':', '_').replace('*', '_') \
                               .replace('?', '_').replace('"', '_') \
                               .replace('<', '_').replace('>', '_') \
                               .replace('|', '_')

    base_path = f"reviews_{safe_name}.json"
    if not os.path.exists(base_path):
        return base_path

    i = 1
    while True:
        new_path = f"reviews_{safe_name}_{i}.json"
        if not os.path.exists(new_path):
            return new_path
        i += 1

def analyze(restaurant_name):
    # 1. API로 리뷰 수집 (크롤링 없음)
    reviews = get_blog_reviews(restaurant_name, display=20)

    if not reviews:
        print("리뷰를 찾을 수 없습니다.")
        return []

    # 2. 저장
    save_path = get_save_path(restaurant_name)
    with open(save_path, 'w', encoding='utf-8') as f:
        json.dump(reviews, f, ensure_ascii=False, indent=2)
    print(f"저장 완료: {save_path}")

    return reviews

if __name__ == "__main__":
    restaurant_name = input("식당 이름을 입력하세요: ")
    analyze(restaurant_name)