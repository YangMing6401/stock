"""
上櫃股票三大法人買賣超抓取 (TPEx)
資料來源：證券櫃檯買賣中心 OpenAPI + Web API
"""
import requests
import time
import logging
from config import REQUEST_HEADERS, REQUEST_DELAY
from database import insert_institutional, log_fetch

logger = logging.getLogger(__name__)

# TPEx OpenAPI - 三大法人買賣超 (最新交易日)
TPEX_OPENAPI_3INSTI = "https://www.tpex.org.tw/openapi/v1/tpex_3insti_daily_trading"

# TPEx Web API - 指定日期查詢
TPEX_3INSTI_URL = "https://www.tpex.org.tw/web/stock/3insti/daily_trade/3itrade_hedge_result.php"


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


def _parse_int(text):
    """解析整數字串"""
    if not text or str(text).strip() in ('--', '', '---', '0'):
        return 0
    try:
        cleaned = str(text).replace(",", "").replace(" ", "").strip()
        return int(float(cleaned))
    except (ValueError, TypeError):
        return 0


def fetch_tpex_institutional(date_str):
    """
    抓取上櫃三大法人買賣超
    date_str: YYYYMMDD 格式

    策略：優先使用 Web API，若失敗則改用 OpenAPI
    """
    logger.info(f"抓取上櫃三大法人買賣超: {date_str}")

    formatted_date = f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"

    # 嘗試方法1: Web API
    count = _fetch_via_web_api(date_str, formatted_date)
    if count > 0:
        return count

    # 嘗試方法2: OpenAPI
    count = _fetch_via_openapi(date_str, formatted_date)
    return count


def _fetch_via_web_api(date_str, formatted_date):
    """使用 TPEx Web API 抓取"""
    roc_date = _to_roc_date(date_str)

    params = {
        "l": "zh-tw",
        "se": "AL",
        "t": "D",
        "d": roc_date,
        "o": "json"
    }

    try:
        resp = requests.get(TPEX_3INSTI_URL, params=params, headers=REQUEST_HEADERS, timeout=30)
        resp.raise_for_status()
        data = resp.json()

        raw_data = data.get("aaData", [])
        if not raw_data:
            logger.info("Web API 無上櫃三大法人資料，嘗試 OpenAPI")
            return 0

        records = []

        for row in raw_data:
            if len(row) < 18:
                continue

            stock_id = str(row[0]).strip()
            if not stock_id.isdigit() or len(stock_id) != 4:
                continue

            # 外資 = 外陸資(不含自營) + 外資自營商
            foreign_buy = _parse_int(row[2]) + _parse_int(row[5])
            foreign_sell = _parse_int(row[3]) + _parse_int(row[6])
            foreign_net = _parse_int(row[4]) + _parse_int(row[7])

            # 投信
            trust_buy = _parse_int(row[8])
            trust_sell = _parse_int(row[9])
            trust_net = _parse_int(row[10])

            # 自營商 = 自行買賣 + 避險
            dealer_buy = _parse_int(row[11]) + _parse_int(row[14])
            dealer_sell = _parse_int(row[12]) + _parse_int(row[15])
            dealer_net = _parse_int(row[13]) + _parse_int(row[16])

            total_net = _parse_int(row[17])

            records.append((
                formatted_date, stock_id,
                foreign_buy, foreign_sell, foreign_net,
                trust_buy, trust_sell, trust_net,
                dealer_buy, dealer_sell, dealer_net,
                total_net
            ))

        if records:
            insert_institutional(records)

        logger.info(f"上櫃三大法人完成 (Web API): {len(records)} 筆")
        log_fetch(date_str, "tpex_institutional", "success", records=len(records))
        return len(records)

    except Exception as e:
        logger.warning(f"TPEx 三大法人 Web API 失敗: {e}")
        return 0
    finally:
        time.sleep(REQUEST_DELAY)


def _fetch_via_openapi(date_str, formatted_date):
    """使用 TPEx OpenAPI 抓取最新交易日資料"""
    try:
        resp = requests.get(TPEX_OPENAPI_3INSTI, headers=REQUEST_HEADERS, timeout=30)
        resp.raise_for_status()
        data = resp.json()

        if not data:
            msg = "OpenAPI 無上櫃三大法人資料"
            logger.warning(msg)
            log_fetch(date_str, "tpex_institutional", "error", message=msg)
            return 0

        records = []
        actual_date = None

        for item in data:
            stock_id = str(item.get("SecuritiesCompanyCode", "")).strip()
            if not stock_id.isdigit() or len(stock_id) != 4:
                continue

            if actual_date is None:
                raw_date = str(item.get("Date", "")).strip()
                actual_date = _roc_to_western(raw_date)

            use_date = actual_date or formatted_date

            # 外資（含外資自營商的合計欄位）
            foreign_buy = _parse_int(item.get("ForeignInvestorsIncludeMainlandAreaInvestors-TotalBuy", 0))
            foreign_sell = _parse_int(item.get("ForeignInvestorsIncludeMainlandAreaInvestors-TotalSell", 0))
            foreign_net = _parse_int(item.get("ForeignInvestorsInclude MainlandAreaInvestors-Difference", 0))

            # 投信
            trust_buy = _parse_int(item.get("SecuritiesInvestmentTrustCompanies-TotalBuy", 0))
            trust_sell = _parse_int(item.get("SecuritiesInvestmentTrustCompanies-TotalSell", 0))
            trust_net = _parse_int(item.get("SecuritiesInvestmentTrustCompanies-Difference", 0))

            # 自營商
            dealer_buy = _parse_int(item.get("Dealers-TotalBuy", 0))
            dealer_sell = _parse_int(item.get("Dealers-TotalSell", 0))
            dealer_net = _parse_int(item.get("Dealers-Difference", 0))

            total_net = _parse_int(item.get("TotalDifference", 0))

            records.append((
                use_date, stock_id,
                foreign_buy, foreign_sell, foreign_net,
                trust_buy, trust_sell, trust_net,
                dealer_buy, dealer_sell, dealer_net,
                total_net
            ))

        if records:
            insert_institutional(records)

        logger.info(f"上櫃三大法人完成 (OpenAPI): {len(records)} 筆 (日期: {actual_date})")
        log_fetch(date_str, "tpex_institutional", "success", records=len(records))
        return len(records)

    except requests.exceptions.RequestException as e:
        logger.error(f"上櫃三大法人請求失敗: {e}")
        log_fetch(date_str, "tpex_institutional", "error", message=str(e))
        return 0
    except Exception as e:
        logger.error(f"上櫃三大法人處理失敗: {e}")
        log_fetch(date_str, "tpex_institutional", "error", message=str(e))
        return 0
    finally:
        time.sleep(REQUEST_DELAY)
