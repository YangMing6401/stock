"""
台股數據追蹤系統 - 資料庫模組
使用 SQLite 儲存所有股票數據
"""
import sqlite3
import logging
from contextlib import contextmanager
from config import DB_PATH

logger = logging.getLogger(__name__)


@contextmanager
def get_connection():
    """取得資料庫連線的 context manager"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db():
    """初始化資料庫 - 建立所有資料表"""
    with get_connection() as conn:
        cursor = conn.cursor()

        # 股票基本資料
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS stocks (
                stock_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                market TEXT NOT NULL CHECK(market IN ('上市', '上櫃'))
            )
        """)

        # 每日行情
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS daily_price (
                date TEXT NOT NULL,
                stock_id TEXT NOT NULL,
                open REAL,
                high REAL,
                low REAL,
                close REAL,
                volume INTEGER,
                turnover INTEGER,
                change REAL,
                transactions INTEGER,
                PRIMARY KEY (date, stock_id)
            )
        """)

        # 三大法人買賣超
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS institutional_trading (
                date TEXT NOT NULL,
                stock_id TEXT NOT NULL,
                foreign_buy INTEGER DEFAULT 0,
                foreign_sell INTEGER DEFAULT 0,
                foreign_net INTEGER DEFAULT 0,
                trust_buy INTEGER DEFAULT 0,
                trust_sell INTEGER DEFAULT 0,
                trust_net INTEGER DEFAULT 0,
                dealer_buy INTEGER DEFAULT 0,
                dealer_sell INTEGER DEFAULT 0,
                dealer_net INTEGER DEFAULT 0,
                total_net INTEGER DEFAULT 0,
                PRIMARY KEY (date, stock_id)
            )
        """)

        # 券商分點進出
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS broker_trading (
                date TEXT NOT NULL,
                stock_id TEXT NOT NULL,
                broker_id TEXT NOT NULL,
                broker_name TEXT,
                price REAL,
                buy INTEGER DEFAULT 0,
                sell INTEGER DEFAULT 0,
                net INTEGER DEFAULT 0,
                PRIMARY KEY (date, stock_id, broker_id)
            )
        """)

        # 抓取紀錄
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS fetch_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                date TEXT NOT NULL,
                task TEXT NOT NULL,
                status TEXT NOT NULL,
                records INTEGER DEFAULT 0,
                message TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

        # 建立索引以加速查詢
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_daily_price_date ON daily_price(date)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_daily_price_stock ON daily_price(stock_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_institutional_date ON institutional_trading(date)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_institutional_stock ON institutional_trading(stock_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_broker_date ON broker_trading(date)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_broker_stock ON broker_trading(stock_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_broker_broker ON broker_trading(broker_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_fetch_log_date ON fetch_log(date)")

        logger.info("資料庫初始化完成")


def insert_stocks(stocks_data):
    """批次寫入股票基本資料（upsert）"""
    with get_connection() as conn:
        conn.executemany(
            "INSERT OR REPLACE INTO stocks (stock_id, name, market) VALUES (?, ?, ?)",
            stocks_data
        )
        logger.info(f"寫入 {len(stocks_data)} 筆股票基本資料")


def insert_daily_prices(prices_data):
    """批次寫入每日行情（upsert）"""
    with get_connection() as conn:
        conn.executemany(
            """INSERT OR REPLACE INTO daily_price
            (date, stock_id, open, high, low, close, volume, turnover, change, transactions)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            prices_data
        )
        logger.info(f"寫入 {len(prices_data)} 筆每日行情")


def insert_institutional(data):
    """批次寫入三大法人買賣超（upsert）"""
    with get_connection() as conn:
        conn.executemany(
            """INSERT OR REPLACE INTO institutional_trading
            (date, stock_id, foreign_buy, foreign_sell, foreign_net,
             trust_buy, trust_sell, trust_net,
             dealer_buy, dealer_sell, dealer_net, total_net)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            data
        )
        logger.info(f"寫入 {len(data)} 筆三大法人買賣超")


def insert_broker_trading(data):
    """批次寫入券商分點進出（upsert）"""
    with get_connection() as conn:
        conn.executemany(
            """INSERT OR REPLACE INTO broker_trading
            (date, stock_id, broker_id, broker_name, price, buy, sell, net)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            data
        )
        logger.info(f"寫入 {len(data)} 筆券商分點進出")


def log_fetch(date, task, status, records=0, message=""):
    """記錄抓取狀態"""
    with get_connection() as conn:
        conn.execute(
            "INSERT INTO fetch_log (date, task, status, records, message) VALUES (?, ?, ?, ?, ?)",
            (date, task, status, records, message)
        )


def query_stock_list(market=None):
    """查詢股票清單"""
    with get_connection() as conn:
        if market:
            rows = conn.execute(
                "SELECT * FROM stocks WHERE market = ? ORDER BY stock_id", (market,)
            ).fetchall()
        else:
            rows = conn.execute("SELECT * FROM stocks ORDER BY stock_id").fetchall()
        return [dict(r) for r in rows]


def query_daily_price(stock_id=None, date=None, start_date=None, end_date=None, limit=60):
    """查詢每日行情"""
    with get_connection() as conn:
        sql = """
            SELECT dp.*, s.name as stock_name
            FROM daily_price dp
            LEFT JOIN stocks s ON dp.stock_id = s.stock_id
            WHERE 1=1
        """
        params = []

        if stock_id:
            sql += " AND dp.stock_id = ?"
            params.append(stock_id)
        if date:
            sql += " AND dp.date = ?"
            params.append(date)
        if start_date:
            sql += " AND dp.date >= ?"
            params.append(start_date)
        if end_date:
            sql += " AND dp.date <= ?"
            params.append(end_date)

        sql += " ORDER BY dp.date DESC, dp.stock_id"

        if limit:
            sql += " LIMIT ?"
            params.append(limit)

        rows = conn.execute(sql, params).fetchall()
        return [dict(r) for r in rows]


def query_institutional(stock_id=None, date=None, start_date=None, end_date=None, limit=60):
    """查詢三大法人買賣超"""
    with get_connection() as conn:
        sql = """
            SELECT it.*, s.name as stock_name
            FROM institutional_trading it
            LEFT JOIN stocks s ON it.stock_id = s.stock_id
            WHERE 1=1
        """
        params = []

        if stock_id:
            sql += " AND it.stock_id = ?"
            params.append(stock_id)
        if date:
            sql += " AND it.date = ?"
            params.append(date)
        if start_date:
            sql += " AND it.date >= ?"
            params.append(start_date)
        if end_date:
            sql += " AND it.date <= ?"
            params.append(end_date)

        sql += " ORDER BY it.date DESC, ABS(it.total_net) DESC"

        if limit:
            sql += " LIMIT ?"
            params.append(limit)

        rows = conn.execute(sql, params).fetchall()
        return [dict(r) for r in rows]


def query_broker_trading(stock_id=None, date=None, broker_id=None,
                         start_date=None, end_date=None, limit=100):
    """查詢券商分點進出"""
    with get_connection() as conn:
        sql = """
            SELECT bt.*, s.name as stock_name
            FROM broker_trading bt
            LEFT JOIN stocks s ON bt.stock_id = s.stock_id
            WHERE 1=1
        """
        params = []

        if stock_id:
            sql += " AND bt.stock_id = ?"
            params.append(stock_id)
        if date:
            sql += " AND bt.date = ?"
            params.append(date)
        if broker_id:
            sql += " AND bt.broker_id = ?"
            params.append(broker_id)
        if start_date:
            sql += " AND bt.date >= ?"
            params.append(start_date)
        if end_date:
            sql += " AND bt.date <= ?"
            params.append(end_date)

        sql += " ORDER BY bt.date DESC, ABS(bt.net) DESC"

        if limit:
            sql += " LIMIT ?"
            params.append(limit)

        rows = conn.execute(sql, params).fetchall()
        return [dict(r) for r in rows]


def query_fetch_log(limit=50):
    """查詢抓取紀錄"""
    with get_connection() as conn:
        rows = conn.execute(
            "SELECT * FROM fetch_log ORDER BY created_at DESC LIMIT ?", (limit,)
        ).fetchall()
        return [dict(r) for r in rows]


def get_available_dates():
    """取得所有可查詢的日期"""
    with get_connection() as conn:
        rows = conn.execute(
            "SELECT DISTINCT date FROM daily_price ORDER BY date DESC LIMIT 60"
        ).fetchall()
        return [r['date'] for r in rows]


def get_db_stats():
    """取得資料庫統計資訊"""
    with get_connection() as conn:
        stats = {}
        for table in ['stocks', 'daily_price', 'institutional_trading', 'broker_trading']:
            count = conn.execute(f"SELECT COUNT(*) as cnt FROM {table}").fetchone()['cnt']
            stats[table] = count

        # 最新資料日期
        latest = conn.execute(
            "SELECT MAX(date) as d FROM daily_price"
        ).fetchone()['d']
        stats['latest_date'] = latest or '尚無資料'

        return stats
