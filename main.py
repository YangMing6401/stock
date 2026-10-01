"""
台股數據追蹤系統 - CLI 主程式
支援手動抓取與查詢
"""
import sys
import os
import argparse
import logging
from datetime import datetime, timedelta

# 修正 Windows 主控台編碼問題
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# 設定 logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger(__name__)

from database import init_db, get_db_stats, query_fetch_log
from fetchers.twse_daily import fetch_twse_daily
from fetchers.tpex_daily import fetch_tpex_daily
from fetchers.twse_institutional import fetch_twse_institutional
from fetchers.tpex_institutional import fetch_tpex_institutional
from fetchers.broker_trading import fetch_broker_trading


def fetch_all(date_str):
    """抓取指定日期的所有資料"""
    logger.info(f"========== 開始抓取 {date_str} 所有資料 ==========")
    results = {}

    # 1. 上市每日行情
    results['twse_daily'] = fetch_twse_daily(date_str)

    # 2. 上櫃每日行情
    results['tpex_daily'] = fetch_tpex_daily(date_str)

    # 3. 上市三大法人
    results['twse_institutional'] = fetch_twse_institutional(date_str)

    # 4. 上櫃三大法人
    results['tpex_institutional'] = fetch_tpex_institutional(date_str)

    # 5. 券商分點進出
    results['broker_trading'] = fetch_broker_trading(date_str)

    logger.info(f"========== 抓取完成 ==========")
    for task, count in results.items():
        status = "✓" if count > 0 else "✗"
        logger.info(f"  {status} {task}: {count} 筆")

    return results


def fetch_daily_only(date_str):
    """只抓取每日行情"""
    logger.info(f"抓取每日行情: {date_str}")
    r1 = fetch_twse_daily(date_str)
    r2 = fetch_tpex_daily(date_str)
    logger.info(f"上市: {r1} 筆, 上櫃: {r2} 筆")
    return r1 + r2


def fetch_institutional_only(date_str):
    """只抓取三大法人"""
    logger.info(f"抓取三大法人: {date_str}")
    r1 = fetch_twse_institutional(date_str)
    r2 = fetch_tpex_institutional(date_str)
    logger.info(f"上市: {r1} 筆, 上櫃: {r2} 筆")
    return r1 + r2


def fetch_broker_only(date_str):
    """只抓取券商分點"""
    logger.info(f"抓取券商分點: {date_str}")
    r = fetch_broker_trading(date_str)
    logger.info(f"券商分點: {r} 筆")
    return r


def get_last_trading_day():
    """取得最近一個交易日 (簡單邏輯：排除週末)"""
    today = datetime.now()
    # 如果是收盤前，抓前一天的
    if today.hour < 14:
        today = today - timedelta(days=1)

    while today.weekday() >= 5:  # 週六=5, 週日=6
        today = today - timedelta(days=1)

    return today.strftime("%Y%m%d")


def show_stats():
    """顯示資料庫統計"""
    stats = get_db_stats()
    print("\n" + "=" * 50)
    print("  📊 台股數據追蹤系統 - 資料庫統計")
    print("=" * 50)
    print(f"  股票數量:       {stats.get('stocks', 0):>10,} 檔")
    print(f"  每日行情:       {stats.get('daily_price', 0):>10,} 筆")
    print(f"  三大法人:       {stats.get('institutional_trading', 0):>10,} 筆")
    print(f"  券商分點:       {stats.get('broker_trading', 0):>10,} 筆")
    print(f"  最新資料日期:   {stats.get('latest_date', '尚無資料')}")
    print("=" * 50 + "\n")


def show_fetch_log():
    """顯示抓取紀錄"""
    logs = query_fetch_log(limit=20)
    print("\n" + "=" * 80)
    print("  📝 最近抓取紀錄")
    print("=" * 80)
    print(f"  {'時間':<20} {'日期':<12} {'任務':<22} {'狀態':<8} {'筆數':>8}")
    print("-" * 80)
    for log in logs:
        print(f"  {log['created_at']:<20} {log['date']:<12} {log['task']:<22} {log['status']:<8} {log['records']:>8}")
    print("=" * 80 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="台股數據追蹤系統",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
使用範例:
  python main.py fetch --date 20260929              抓取指定日期所有資料
  python main.py fetch                              抓取最近交易日所有資料
  python main.py fetch --type daily --date 20260929 只抓每日行情
  python main.py fetch --type institutional         只抓三大法人
  python main.py fetch --type broker                只抓券商分點
  python main.py fetch --range 20260901 20260930    抓取日期區間
  python main.py stats                              顯示資料庫統計
  python main.py log                                顯示抓取紀錄
  python main.py web                                啟動 Web 查詢介面
        """
    )

    subparsers = parser.add_subparsers(dest="command", help="可用指令")

    # fetch 指令
    fetch_parser = subparsers.add_parser("fetch", help="抓取資料")
    fetch_parser.add_argument("--date", type=str, help="指定日期 (YYYYMMDD)")
    fetch_parser.add_argument("--type", type=str,
                              choices=["all", "daily", "institutional", "broker"],
                              default="all", help="抓取類型")
    fetch_parser.add_argument("--range", nargs=2, metavar=("START", "END"),
                              help="日期區間 (YYYYMMDD YYYYMMDD)")

    # stats 指令
    subparsers.add_parser("stats", help="顯示資料庫統計")

    # log 指令
    subparsers.add_parser("log", help="顯示抓取紀錄")

    # web 指令
    web_parser = subparsers.add_parser("web", help="啟動 Web 介面")
    web_parser.add_argument("--port", type=int, default=5000, help="Web 伺服器埠號")

    args = parser.parse_args()

    # 初始化資料庫
    init_db()

    if args.command == "fetch":
        if args.range:
            # 日期區間抓取
            start = datetime.strptime(args.range[0], "%Y%m%d")
            end = datetime.strptime(args.range[1], "%Y%m%d")
            current = start
            while current <= end:
                if current.weekday() < 5:  # 排除週末
                    date_str = current.strftime("%Y%m%d")
                    if args.type == "daily":
                        fetch_daily_only(date_str)
                    elif args.type == "institutional":
                        fetch_institutional_only(date_str)
                    elif args.type == "broker":
                        fetch_broker_only(date_str)
                    else:
                        fetch_all(date_str)
                current += timedelta(days=1)
        else:
            date_str = args.date or get_last_trading_day()
            if args.type == "daily":
                fetch_daily_only(date_str)
            elif args.type == "institutional":
                fetch_institutional_only(date_str)
            elif args.type == "broker":
                fetch_broker_only(date_str)
            else:
                fetch_all(date_str)

        show_stats()

    elif args.command == "stats":
        show_stats()

    elif args.command == "log":
        show_fetch_log()

    elif args.command == "web":
        from web.app import create_app
        app = create_app()
        port = args.port
        print(f"\n🌐 Web 介面啟動中: http://localhost:{port}\n")
        app.run(host="0.0.0.0", port=port, debug=True)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
