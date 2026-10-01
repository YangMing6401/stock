"""
上櫃股票每日行情抓取 (TPEx)
資料來源：證券櫃檯買賣中心 OpenAPI
"""
import requests
import time
import logging
from config import REQUEST_HEADERS, REQUEST_DELAY
from database import insert_stocks, insert_daily_prices, log_fetch

logger = logging.getLogger(__name__)

# TPEx OpenAPI - 每日收盤行情 (只返回最新交易日)
TPEX_OPENAPI_DAILY = "https://www.tpex.org.tw/openapi/v1/tpex_mainboard_daily_close_quotes"

# TPEx Web API - 指定日期查詢
TPEX_DAILY_URL = "https://www.tpex.org.tw/web/stock/aftertrading/otc_quotes_no1430/stk_wn1430_result.php"


def _to_roc_date(date_str):
    """將 YYYYMMDD 轉為民國年格式 YYY/MM/DD"""
    year = int(date_str[:4]) - 1911
    month = date_str[4:6]
    day = date_str[6:8]
    return f"{year}/{month}/{day}"


def _roc_to_western(roc_date_str):
    """將民國年日期 (YYYMMDD) 轉為 YYYY-MM-DD"""
    roc_date_str = str(roc_date_str).strip()
    if len(roc_date_str) == 7:
        year = int(roc_date_str[:3]) + 1911
        month = roc_date_str[3:5]
        day = roc_date_str[5:7]
        return f"{year}-{month}-{day}"
    return roc_date_str


def _parse_number(text):
    """解析數字字串"""
    if not text or str(text).strip() in ('--', '', '---', 'N/A', '除權', '除息'):
        return None
    try:
        cleaned = str(text).replace(",", "").replace(" ", "").strip()
        if cleaned.startswith("+"):
            cleaned = cleaned[1:]
        return float(cleaned)
    except (ValueError, TypeError):
        return None


def _parse_int(text):
    """解析整數字串"""
    val = _parse_number(text)
    return int(val) if val is not None else None


def fetch_tpex_daily(date_str):
    """
    抓取上櫃股票每日行情
    date_str: YYYYMMDD 格式

    策略：優先使用 Web API (可指定日期)，若失敗則改用 OpenAPI (只有最新日)
    """
    logger.info(f"抓取上櫃每日行情: {date_str}")

    formatted_date = f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"

    # 嘗試方法1: Web API (可指定日期)
    count = _fetch_via_web_api(date_str, formatted_date)
    if count > 0:
        return count

    # 嘗試方法2: OpenAPI (只有最新交易日資料)
    count = _fetch_via_openapi(date_str, formatted_date)
    return count


def _fetch_via_web_api(date_str, formatted_date):
    """使用 TPEx Web API 抓取指定日期資料"""
    roc_date = _to_roc_date(date_str)

    params = {
        "l": "zh-tw",
        "d": roc_date,
        "se": "AL",
        "o": "json"
    }

    try:
        resp = requests.get(TPEX_DAILY_URL, params=params, headers=REQUEST_HEADERS, timeout=30)
        resp.raise_for_status()
        data = resp.json()

        # 嘗試 aaData 格式
        price_data = data.get("aaData", [])

        # 嘗試 tables 格式
        if not price_data and "tables" in data:
            for table in data["tables"]:
                tdata = table.get("data", [])
                if len(tdata) > len(price_data):
                    price_data = tdata

        if not price_data:
            logger.info("Web API 無上櫃行情資料，嘗試 OpenAPI")
            return 0

        records = []
        stocks = []

        for row in price_data:
            if len(row) < 10:
                continue

            stock_id = str(row[0]).strip()
            if not stock_id.isdigit() or len(stock_id) != 4:
                continue

            name = str(row[1]).strip()

            close_price = _parse_number(row[2])
            change = _parse_number(row[3])
            open_price = _parse_number(row[4])
            high_price = _parse_number(row[5])
            low_price = _parse_number(row[6])
            volume = _parse_int(row[7])
            turnover = _parse_int(row[8])
            transactions = _parse_int(row[9])

            # 上櫃的成交股數與金額單位可能是千股/千元
            if volume is not None:
                volume = volume * 1000
            if turnover is not None:
                turnover = turnover * 1000

            stocks.append((stock_id, name, "上櫃"))
            records.append((
                formatted_date, stock_id,
                open_price, high_price, low_price, close_price,
                volume, turnover, change, transactions
            ))

        if stocks:
            insert_stocks(stocks)
        if records:
            insert_daily_prices(records)

        logger.info(f"上櫃每日行情完成 (Web API): {len(records)} 筆")
        log_fetch(formatted_date.replace("-", ""), "tpex_daily", "success", records=len(records))
        return len(records)

    except Exception as e:
        logger.warning(f"TPEx Web API 失敗: {e}")
        return 0
    finally:
        time.sleep(REQUEST_DELAY)


def _fetch_via_openapi(date_str, formatted_date):
    """使用 TPEx OpenAPI 抓取最新交易日資料"""
    try:
        resp = requests.get(TPEX_OPENAPI_DAILY, headers=REQUEST_HEADERS, timeout=30)
        resp.raise_for_status()
        data = resp.json()

        if not data:
            msg = "OpenAPI 無上櫃行情資料"
            logger.warning(msg)
            log_fetch(date_str, "tpex_daily", "error", message=msg)
            return 0

        records = []
        stocks = []
        actual_date = None

        for item in data:
            stock_id = str(item.get("SecuritiesCompanyCode", "")).strip()
            if not stock_id.isdigit() or len(stock_id) != 4:
                continue

            name = str(item.get("CompanyName", "")).strip()

            # 轉換日期
            if actual_date is None:
                raw_date = str(item.get("Date", "")).strip()
                actual_date = _roc_to_western(raw_date)

            close_price = _parse_number(item.get("Close"))
            change = _parse_number(item.get("Change"))
            open_price = _parse_number(item.get("Open"))
            high_price = _parse_number(item.get("High"))
            low_price = _parse_number(item.get("Low"))
            volume = _parse_int(item.get("TradingShares"))
            turnover = _parse_int(item.get("TransactionAmount"))
            transactions = _parse_int(item.get("TransactionNumber"))

            use_date = actual_date or formatted_date

            stocks.append((stock_id, name, "上櫃"))
            records.append((
                use_date, stock_id,
                open_price, high_price, low_price, close_price,
                volume, turnover, change, transactions
            ))

        if stocks:
            insert_stocks(stocks)
        if records:
            insert_daily_prices(records)

        logger.info(f"上櫃每日行情完成 (OpenAPI): {len(records)} 筆 (日期: {actual_date})")
        log_fetch(date_str, "tpex_daily", "success", records=len(records))
        return len(records)

    except requests.exceptions.RequestException as e:
        logger.error(f"上櫃每日行情請求失敗: {e}")
        log_fetch(date_str, "tpex_daily", "error", message=str(e))
        return 0
    except Exception as e:
        logger.error(f"上櫃每日行情處理失敗: {e}")
        log_fetch(date_str, "tpex_daily", "error", message=str(e))
        return 0
    finally:
        time.sleep(REQUEST_DELAY)
