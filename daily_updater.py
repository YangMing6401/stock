"""
台股每日自動更新程式 (Daily Updater)
每日下午盤後自動抓取：
1. 上市/上櫃每日收盤行情 (成交量、成交金額、開高低收)
2. 上市/上櫃三大法人買賣超 (外資、投信、自營商買賣超金額與張數)
3. 券商分點進出 (若 Token 支援)
"""
import sys
import os
import io
import argparse
import logging
from datetime import datetime, timedelta

# 設定 UTF-8 輸出
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# 確保當前目錄在 sys.path
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from database import init_db, get_db_stats
from fetchers.twse_daily import fetch_twse_daily
from fetchers.tpex_daily import fetch_tpex_daily
from fetchers.twse_institutional import fetch_twse_institutional
from fetchers.tpex_institutional import fetch_tpex_institutional
from fetchers.broker_trading import fetch_broker_trading

# 設定日誌
log_file = os.path.join(BASE_DIR, "updater.log")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(log_file, encoding='utf-8')
    ]
)
logger = logging.getLogger("DailyUpdater")


def get_target_date():
    """自動取得應抓取的交易日期"""
    now = datetime.now()
    # 週六 (5) 或 週日 (6) 回推到週五
    weekday = now.weekday()
    if weekday == 5:
        target = now - timedelta(days=1)
    elif weekday == 6:
        target = now - timedelta(days=2)
    else:
        # 平日如果還沒過 15:30（盤後資料通常 15:00~16:00 公布），且今天是週一則回推上週五
        if now.hour < 15 or (now.hour == 15 and now.minute < 30):
            if weekday == 0:
                target = now - timedelta(days=3)
            else:
                target = now - timedelta(days=1)
        else:
            target = now

    return target.strftime("%Y%m%d")


def run_update(date_str=None):
    """執行每日更新"""
    init_db()

    if not date_str:
        date_str = get_target_date()

    logger.info("=" * 55)
    logger.info(f"🚀 開始執行台股盤後資料更新: {date_str}")
    logger.info("=" * 55)

    results = {}

    # 1. 上市每日行情
    try:
        results['上市行情'] = fetch_twse_daily(date_str)
    except Exception as e:
        logger.error(f"上市行情抓取失敗: {e}")
        results['上市行情'] = 0

    # 2. 上櫃每日行情
    try:
        results['上櫃行情'] = fetch_tpex_daily(date_str)
    except Exception as e:
        logger.error(f"上櫃行情抓取失敗: {e}")
        results['上櫃行情'] = 0

    # 3. 上市三大法人
    try:
        results['上市三大法人'] = fetch_twse_institutional(date_str)
    except Exception as e:
        logger.error(f"上市三大法人抓取失敗: {e}")
        results['上市三大法人'] = 0

    # 4. 上櫃三大法人
    try:
        results['上櫃三大法人'] = fetch_tpex_institutional(date_str)
    except Exception as e:
        logger.error(f"上櫃三大法人抓取失敗: {e}")
        results['上櫃三大法人'] = 0

    # 5. 券商分點進出
    try:
        results['券商分點'] = fetch_broker_trading(date_str)
    except Exception as e:
        logger.error(f"券商分點抓取失敗: {e}")
        results['券商分點'] = 0

    logger.info("=" * 55)
    logger.info("🎉 今日更新結果統計：")
    for name, cnt in results.items():
        status = "✅ 成功" if cnt > 0 else "⚠️ 0 筆"
        logger.info(f"   {name:<12} : {cnt:>6} 筆 ({status})")

    stats = get_db_stats()
    logger.info("-" * 55)
    logger.info(f"📊 資料庫現有累積總量：")
    logger.info(f"   股票檔數: {stats['stocks']:,} 檔 | 最新日期: {stats['latest_date']}")
    logger.info(f"   行情筆數: {stats['daily_price']:,} 筆 | 三大法人: {stats['institutional_trading']:,} 筆 | 券商分點: {stats['broker_trading']:,} 筆")
    logger.info("=" * 55)

    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="台股每日自動更新程式")
    parser.add_argument("--date", help="指定抓取日期 (格式: YYYYMMDD)，若無指定則自動判斷最新交易日")
    args = parser.parse_args()

    run_update(args.date)
