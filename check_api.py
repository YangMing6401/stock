import requests
import json

r = requests.get(
    'https://www.tpex.org.tw/web/stock/aftertrading/otc_quotes_no1430/stk_wn1430_result.php',
    params={'l': 'zh-tw', 'd': '115/09/29', 'se': 'AL', 'o': 'json'},
    headers={'User-Agent': 'Mozilla/5.0'}
)

d = r.json()
print('Keys:', list(d.keys()))
print('stat:', d.get('stat'))
print('date:', d.get('date'))

# Check tables format
tables = d.get('tables', [])
print(f'\nTables count: {len(tables)}')
for i, t in enumerate(tables):
    title = t.get('title', '?')
    fields = t.get('fields', [])
    data = t.get('data', [])
    print(f'\nTable {i}:')
    print(f'  title: {title}')
    print(f'  fields: {fields[:5]}...')
    print(f'  data count: {len(data)}')
    if data:
        print(f'  first row: {data[0][:5]}')

# Also check aaData
aa = d.get('aaData', [])
print(f'\naaData count: {len(aa)}')
if aa:
    print(f'First: {aa[0][:5]}')

# Check reportDate
print(f'\nflagField: {d.get("flagField")}')
