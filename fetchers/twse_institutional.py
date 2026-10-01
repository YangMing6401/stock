"""
上市股票三大法人買賣超抓取 (TWSE T86)
資料來源：台灣證券交易所
"""
import requests
import time
import logging
from config import REQUEST_HEADERS, REQUEST_DELAY
from database import insert_institutional, log_fetch

logger = logging.getLogger(__name__)

TWSE_T86_URL = "https://www.twse.com.tw/fund/T86"


def _parse_int(text):
    """解析整數字串，移除逗號"""
    if not text or str(text).strip() in ('--', '', '---'):
        return 0
    try:
        cleaned = str(text).replace(",", "").replace(" ", "").strip()
        return int(float(cleaned))
    except (ValueError, TypeError):
        return 0


def fetch_twse_institutional(date_str):
    """
    抓取上市三大法人買賣超
    date_str: YYYYMMDD 格式

    T86 欄位順序:
    證券代號, 證券名稱,
    外陸資買進股數(不含外資自營商), 外陸資賣出股數(不含外資自營商), 外陸資買賣超股數(不含外資自營商),
    外資自營商買進股數, 外資自營商賣出股數, 外資自營商買賣超股數,
    投信買進股數, 投信賣出股數, 投信買賣超股數,
    自營商買賣超股數, 自營商買進股數(自行買賣), 自營商賣出股數(自行買賣), 自營商買賣超股數(自行買賣),
    自營商買進股數(避險), 自營商賣出股數(避險), 自營商買賣超股數(避險),
    三大法人買賣超股數
    """
    logger.info(f"抓取上市三大法人買賣超: {date_str}")

    params = {
        "response": "json",
        "date": date_str,
        "selectType": "ALLBUT0999"
    }

    try:
        resp = requests.get(TWSE_T86_URL, params=params, headers=REQUEST_HEADERS, timeout=30)
        resp.raise_for_status()
        data = resp.json()

        if data.get("stat") != "OK":
            msg = data.get("stat", "未知狀態")
            logger.warning(f"TWSE T86 回傳狀態異常: {msg}")
            log_fetch(date_str, "twse_institutional", "error", message=msg)
            return 0

        raw_data = data.get("data", [])
        if not raw_data:
            log_fetch(date_str, "twse_institutional", "error", message="無資料")
            return 0

        formatted_date = f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"
        records = []

        for row in raw_data:
            if len(row) < 19:
                continue

            stock_id = str(row[0]).strip()
            if not stock_id.isdigit() or len(stock_id) > 6:
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
            dealer_buy = _parse_int(row[12]) + _parse_int(row[15])
            dealer_sell = _parse_int(row[13]) + _parse_int(row[16])
            dealer_net = _parse_int(row[14]) + _parse_int(row[17])

            # 三大法人合計
            total_net = _parse_int(row[18])

            records.append((
                formatted_date, stock_id,
                foreign_buy, foreign_sell, foreign_net,
                trust_buy, trust_sell, trust_net,
                dealer_buy, dealer_sell, dealer_net,
                total_net
            ))

        if records:
            insert_institutional(records)

        logger.info(f"上市三大法人完成: {len(records)} 筆")
        log_fetch(date_str, "twse_institutional", "success", records=len(records))
        return len(records)

    except requests.exceptions.RequestException as e:
        logger.error(f"上市三大法人請求失敗: {e}")
        log_fetch(date_str, "twse_institutional", "error", message=str(e))
        return 0
    except Exception as e:
        logger.error(f"上市三大法人處理失敗: {e}")
        log_fetch(date_str, "twse_institutional", "error", message=str(e))
        return 0
    finally:
        time.sleep(REQUEST_DELAY)
