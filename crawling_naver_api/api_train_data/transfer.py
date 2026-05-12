import json
import csv
import glob

# 현재 폴더의 모든 JSON 파일 가져오기
json_files = glob.glob('*.json')

all_data = []

for file in json_files:
    with open(file, 'r', encoding='utf-8') as f:
        json_data = json.load(f)
    
    # JSON이 dict인 경우 리스트로 감싸기
    if isinstance(json_data, dict):
        json_data = [json_data]
    
    all_data.extend(json_data)
    print(f"{file} → {len(json_data)}건 추가")

# 하나의 CSV로 저장
with open('merged.csv', 'w', newline='', encoding='utf-8-sig') as f:
    writer = csv.DictWriter(f, fieldnames=all_data[0].keys())
    writer.writeheader()
    writer.writerows(all_data)

print(f"\n변환 완료: merged.csv ({len(all_data)}건 총합)")