"""
上市股票每日行情抓取 (TWSE)
資料來源：台灣證券交易所
"""
import requests
import time
import logging
from config import REQUEST_HEADERS, REQUEST_DELAY
from database import insert_stocks, insert_daily_prices, log_fetch

logger = logging.getLogger(__name__)

# TWSE 全市場每日收盤行情
TWSE_MI_INDEX_URL = "https://www.twse.com.tw/exchangeReport/MI_INDEX"


def _parse_number(text):
    """解析數字字串，移除逗號與特殊符號"""
    if not text or text.strip() in ('--', '', 'X', 'x'):
        return None
    try:
        cleaned = str(text).replace(",", "").replace(" ", "").strip()
        # 處理 +/- 符號
        if cleaned.startswith("+"):
            cleaned = cleaned[1:]
        return float(cleaned)
    except (ValueError, TypeError):
        return None


def _parse_int(text):
    """解析整數字串"""
    val = _parse_number(text)
    return int(val) if val is not None else None


def _parse_change(direction, value):
    """解析漲跌幅 (結合方向符號)"""
    val = _parse_number(value)
    if val is None:
        return None
    if direction and direction.strip() in ('-', '<p style= color:green>-</p>'):
        return -val
    return val


def fetch_twse_daily(date_str):
    """
    抓取上市股票每日行情
    date_str: YYYYMMDD 格式
    """
    logger.info(f"抓取上市每日行情: {date_str}")

    params = {
        "response": "json",
        "date": date_str,
        "type": "ALL"
    }

    try:
        resp = requests.get(TWSE_MI_INDEX_URL, params=params, headers=REQUEST_HEADERS, timeout=30)
        resp.raise_for_status()
        data = resp.json()

        if data.get("stat") != "OK":
            msg = data.get("stat", "未知狀態")
            logger.warning(f"TWSE 回傳狀態異常: {msg}")
            log_fetch(date_str, "twse_daily", "error", message=msg)
            return 0

        # 每日行情資料在 tables 陣列中
        # MI_INDEX 回傳多個表格，個股行情是最大的那個表格 (通常 index 8)
        records = []
        stocks = []

        price_data = None
        price_fields = None

        # 優先嘗試 tables 格式 (目前 TWSE 主要回傳格式)
        if "tables" in data:
            # 找最大的表格，且欄位包含「證券代號」相關字樣
            best_table = None
            best_count = 0
            for table in data["tables"]:
                tdata = table.get("data", [])
                fields = table.get("fields", [])
                # 行情表格特徵：大量資料，且第一筆資料的第一欄是代號格式
                if len(tdata) > best_count and len(fields) >= 10:
                    # 檢查是否有看起來像股票代號的資料
                    if tdata and len(tdata[0]) >= 10:
                        best_table = table
                        best_count = len(tdata)

            if best_table:
                price_data = best_table.get("data", [])
                price_fields = best_table.get("fields", [])

        # 回退：嘗試 data9, data8 等 key
        if price_data is None:
            for key in ["data9", "data8", "data5"]:
                if key in data:
                    price_data = data[key]
                    field_key = key.replace("data", "fields")
                    price_fields = data.get(field_key, [])
                    break

        if not price_data:
            logger.warning(f"找不到每日行情資料，可用的 keys: {list(data.keys())}")
            log_fetch(date_str, "twse_daily", "error", message="找不到行情資料")
            return 0

        formatted_date = f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"

        for row in price_data:
            if len(row) < 10:
                continue

            stock_id = str(row[0]).strip()

            # 只處理一般股票代號（4位數字的普通股）
            if not stock_id.isdigit() or len(stock_id) != 4:
                continue

            name = str(row[1]).strip()

            # 解析各欄位
            volume = _parse_int(row[2])        # 成交股數
            transactions = _parse_int(row[3])  # 成交筆數
            turnover = _parse_int(row[4])      # 成交金額
            open_price = _parse_number(row[5]) # 開盤價
            high_price = _parse_number(row[6]) # 最高價
            low_price = _parse_number(row[7])  # 最低價
            close_price = _parse_number(row[8]) # 收盤價

            # 漲跌(+/-)在 row[9]，漲跌價差在 row[10]
            change = None
            if len(row) > 10:
                change = _parse_change(row[9], row[10])

            stocks.append((stock_id, name, "上市"))
            records.append((
                formatted_date, stock_id,
                open_price, high_price, low_price, close_price,
                volume, turnover, change, transactions
            ))

        if stocks:
            insert_stocks(stocks)
        if records:
            insert_daily_prices(records)

        logger.info(f"上市每日行情完成: {len(records)} 筆")
        log_fetch(date_str, "twse_daily", "success", records=len(records))
        return len(records)

    except requests.exceptions.RequestException as e:
        logger.error(f"上市每日行情請求失敗: {e}")
        log_fetch(date_str, "twse_daily", "error", message=str(e))
        return 0
    except Exception as e:
        logger.error(f"上市每日行情處理失敗: {e}")
        log_fetch(date_str, "twse_daily", "error", message=str(e))
        return 0
    finally:
        time.sleep(REQUEST_DELAY)
