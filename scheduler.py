"""
台股數據追蹤系統 - 排程自動抓取
每日自動在指定時間抓取當天資料
"""
import schedule
import time
import logging
from datetime import datetime
from config import SCHEDULE_HOUR, SCHEDULE_MINUTE
from database import init_db
from main import fetch_all, get_last_trading_day

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger(__name__)


def scheduled_fetch():
    """排程抓取任務"""
    today = datetime.now()

    # 週末不抓取
    if today.weekday() >= 5:
        logger.info("今天是週末，跳過抓取")
        return

    date_str = today.strftime("%Y%m%d")
    logger.info(f"排程啟動: 抓取 {date_str} 資料")

    try:
        fetch_all(date_str)
    except Exception as e:
        logger.error(f"排程抓取失敗: {e}")


def main():
    init_db()

    schedule_time = f"{SCHEDULE_HOUR:02d}:{SCHEDULE_MINUTE:02d}"
    logger.info(f"排程已啟動，每日 {schedule_time} 自動抓取")
    logger.info("按 Ctrl+C 結束排程")

    schedule.every().day.at(schedule_time).do(scheduled_fetch)

    while True:
        schedule.run_pending()
        time.sleep(60)


if __name__ == "__main__":
    main()
