"""
券商分點進出抓取
資料來源：FinMind API

注意：FinMind 免費 (register) 帳號可能無法使用全市場查詢，
需要指定 data_id (股票代號) 並使用 start_date/end_date 參數。
若帳號等級不足，會自動嘗試逐股查詢模式。
"""
import requests
import time
import logging
import pandas as pd
from config import FINMIND_API_TOKEN, REQUEST_DELAY
from database import insert_broker_trading, log_fetch, query_stock_list

logger = logging.getLogger(__name__)

FINMIND_API_URL = "https://api.finmindtrade.com/api/v4/data"


def _format_date(date_str):
    """將 YYYYMMDD 轉為 YYYY-MM-DD"""
    return f"{date_str[:4]}-{date_str[4:6]}-{date_str[6:8]}"


def _fetch_single_stock(stock_id, formatted_date):
    """抓取單一股票的券商分點資料"""
    params = {
        "dataset": "TaiwanStockTradingDailyReport",
        "data_id": stock_id,
        "start_date": formatted_date,
        "end_date": formatted_date,
        "token": FINMIND_API_TOKEN,
    }

    try:
        resp = requests.get(FINMIND_API_URL, params=params, timeout=30)

        if resp.status_code == 400:
            return None  # API 限制

        resp.raise_for_status()
        result = resp.json()

        if result.get("status") != 200:
            return None

        raw_data = result.get("data", [])
        if not raw_data:
            return []

        records = []
        for item in raw_data:
            broker_id = str(item.get("securities_trader_id", "")).strip()
            broker_name = str(item.get("securities_trader", "")).strip()
            price = float(item.get("price", 0)) if item.get("price") else 0
            buy = int(item.get("buy", 0))
            sell = int(item.get("sell", 0))
            net = buy - sell

            records.append((
                formatted_date, stock_id, broker_id, broker_name,
                price, buy, sell, net
            ))

        return records

    except Exception:
        return None


def fetch_broker_trading(date_str):
    """
    抓取券商分點進出（全市場）
    date_str: YYYYMMDD 格式

    策略：
    1. 先嘗試全市場查詢（需要較高帳號等級）
    2. 若失敗，改為逐股查詢模式（免費帳號可用，但較慢）
    """
    formatted_date = _format_date(date_str)
    logger.info(f"抓取券商分點進出: {formatted_date}")

    # 策略 1: 嘗試全市場查詢
    count = _fetch_all_market(date_str, formatted_date)
    if count > 0:
        return count
    if count == -1:
        # API 回傳帳號等級不足 (TaiwanStockTradingDailyReport 需要 Sponsor 等級)
        logger.warning("FinMind Token 帳號等級為 register，券商分點資料集需 Sponsor 等級權限。")
        logger.info("💡 提示：如需券商分點資料，請至 FinMind 升級贊助者並於 config.py 更新 Token。")
        log_fetch(date_str, "broker_trading", "skipped",
                  message="帳號等級為 register，券商分點需 Sponsor 等級")
        return 0

    return 0


def _fetch_all_market(date_str, formatted_date):
    """全市場一次查詢"""
    params = {
        "dataset": "TaiwanStockTradingDailyReport",
        "date": formatted_date,
        "token": FINMIND_API_TOKEN,
    }

    try:
        resp = requests.get(FINMIND_API_URL, params=params, timeout=120)

        if resp.status_code == 400:
            result = resp.json()
            msg = result.get("msg", "")
            if "level" in msg.lower() or "sponsor" in msg.lower():
                logger.warning(f"FinMind 帳號等級不足: {msg}")
                return -1  # 表示需要改用逐股查詢
            logger.warning(f"FinMind API 錯誤: {msg}")
            log_fetch(date_str, "broker_trading", "error", message=msg)
            return 0

        resp.raise_for_status()
        result = resp.json()

        if result.get("status") != 200:
            msg = result.get("msg", "未知錯誤")
            if "level" in msg.lower() or "sponsor" in msg.lower():
                return -1
            logger.warning(f"FinMind API 錯誤: {msg}")
            log_fetch(date_str, "broker_trading", "error", message=msg)
            return 0

        raw_data = result.get("data", [])
        if not raw_data:
            msg = f"日期 {formatted_date} 無券商分點資料"
            logger.warning(msg)
            log_fetch(date_str, "broker_trading", "error", message=msg)
            return 0

        df = pd.DataFrame(raw_data)

        records = []
        for _, row in df.iterrows():
            stock_id = str(row.get("stock_id", "")).strip()
            if not stock_id:
                continue

            broker_id = str(row.get("securities_trader_id", "")).strip()
            broker_name = str(row.get("securities_trader", "")).strip()
            price = float(row.get("price", 0)) if row.get("price") else 0
            buy = int(row.get("buy", 0))
            sell = int(row.get("sell", 0))
            net = buy - sell

            records.append((
                formatted_date, stock_id, broker_id, broker_name,
                price, buy, sell, net
            ))

        if records:
            insert_broker_trading(records)

        logger.info(f"券商分點進出完成: {len(records)} 筆")
        log_fetch(date_str, "broker_trading", "success", records=len(records))
        return len(records)

    except requests.exceptions.RequestException as e:
        error_msg = str(e)
        if "400" in error_msg:
            return -1
        logger.error(f"券商分點請求失敗: {e}")
        log_fetch(date_str, "broker_trading", "error", message=error_msg)
        return 0
    except Exception as e:
        logger.error(f"券商分點處理失敗: {e}")
        log_fetch(date_str, "broker_trading", "error", message=str(e))
        return 0
    finally:
        time.sleep(REQUEST_DELAY)


def _fetch_by_stocks(date_str, formatted_date):
    """逐股查詢模式 - 針對免費帳號"""
    stocks = query_stock_list()
    if not stocks:
        logger.warning("股票清單為空，請先抓取每日行情")
        log_fetch(date_str, "broker_trading", "error", message="股票清單為空")
        return 0

    total_records = 0
    success_count = 0
    fail_count = 0

    logger.info(f"開始逐股查詢券商分點，共 {len(stocks)} 檔股票...")

    for i, stock in enumerate(stocks):
        stock_id = stock['stock_id']

        records = _fetch_single_stock(stock_id, formatted_date)

        if records is None:
            fail_count += 1
            if fail_count >= 5:
                logger.error("連續失敗過多，停止券商分點查詢")
                break
            time.sleep(2)
            continue

        if records:
            insert_broker_trading(records)
            total_records += len(records)
            success_count += 1
            fail_count = 0  # 重置連續失敗計數

        # 每 50 檔顯示進度
        if (i + 1) % 50 == 0:
            logger.info(f"  進度: {i+1}/{len(stocks)} | 已取得 {total_records} 筆")

        # 控制請求頻率 (FinMind 免費帳號限制每小時 600 次)
        time.sleep(1)

    logger.info(f"券商分點逐股查詢完成: {total_records} 筆 ({success_count} 檔成功)")
    if total_records > 0:
        log_fetch(date_str, "broker_trading", "success", records=total_records,
                  message=f"逐股模式: {success_count} 檔")
    else:
        log_fetch(date_str, "broker_trading", "error", message="無法取得任何券商分點資料")

    return total_records


def fetch_broker_trading_by_stock(stock_id, date_str):
    """
    抓取特定股票的券商分點進出
    stock_id: 股票代號
    date_str: YYYYMMDD 格式
    """
    formatted_date = _format_date(date_str)
    logger.info(f"抓取個股券商分點: {stock_id} / {formatted_date}")

    records = _fetch_single_stock(stock_id, formatted_date)

    if records is None:
        logger.warning(f"個股券商分點查詢失敗: {stock_id}")
        return 0

    if records:
        insert_broker_trading(records)
        logger.info(f"個股券商分點完成: {stock_id} - {len(records)} 筆")

    return len(records) if records else 0
