import pandas as pd

df = pd.read_csv('merged.csv')

# 컬럼명 변경
df = df.rename(columns={
    'url': 'review_url',
    'title': 'review_title',
    'description': 'review_description',
    'bloggername': 'review_bloggername',
    'postdate': 'review_postdate'
})

df.to_csv('merged_fixed.csv', index=False, encoding='utf-8-sig')
print("완료:", df.columns.tolist())