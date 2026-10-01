"""
台股數據追蹤系統 - 設定檔
"""
import os

# FinMind API Token
FINMIND_API_TOKEN = os.environ.get(
    "FINMIND_API_TOKEN",
    "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoiVGltbXkiLCJlbWFpbCI6Inp6bjk0NjQwMUBnbWFpbC5jb20iLCJ0b2tlbl92ZXJzaW9uIjowfQ.N_YC2RUBEJv6HuUO5avwA9L0hEcMcFnNxAvSz2VhrZc"
)

# 資料庫路徑
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stock_data.db")

# 請求設定
REQUEST_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

# 請求間隔（秒）- 避免被封鎖
REQUEST_DELAY = 3

# Web 伺服器設定
WEB_HOST = "0.0.0.0"
WEB_PORT = 5000
WEB_DEBUG = True

# 排程設定 - 每日自動抓取時間（24小時制）
SCHEDULE_HOUR = 15
SCHEDULE_MINUTE = 0
