"""
台股數據追蹤系統 - Flask Web 應用
"""
import sys
import os

# 確保可以 import 根目錄的模組
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from flask import Flask, render_template, request, jsonify
from database import (
    init_db, get_db_stats, get_available_dates,
    query_stock_list, query_daily_price, query_institutional,
    query_broker_trading, query_fetch_log
)


def create_app():
    app = Flask(__name__)
    app.config['TEMPLATES_AUTO_RELOAD'] = True
    init_db()

    @app.route("/")
    def index():
        stats = get_db_stats()
        dates = get_available_dates()
        return render_template("index.html", stats=stats, dates=dates)

    @app.route("/stock/<stock_id>")
    def stock_detail(stock_id):
        days = request.args.get("days", 60, type=int)
        prices = query_daily_price(stock_id=stock_id, limit=days)
        institutional = query_institutional(stock_id=stock_id, limit=days)
        brokers = query_broker_trading(stock_id=stock_id, limit=200)

        stock_name = ""
        if prices:
            stock_name = prices[0].get("stock_name", stock_id)

        return render_template(
            "stock.html",
            stock_id=stock_id,
            stock_name=stock_name,
            prices=prices,
            institutional=institutional,
            brokers=brokers,
            days=days
        )

    @app.route("/institutional")
    def institutional_page():
        date = request.args.get("date", "")
        dates = get_available_dates()
        data = []
        if date:
            data = query_institutional(date=date, limit=2000)
        elif dates:
            date = dates[0]
            data = query_institutional(date=date, limit=2000)
        return render_template("institutional.html", data=data, dates=dates, selected_date=date)

    @app.route("/broker")
    def broker_page():
        stock_id = request.args.get("stock_id", "")
        date = request.args.get("date", "")
        dates = get_available_dates()
        data = []
        if stock_id and date:
            data = query_broker_trading(stock_id=stock_id, date=date, limit=500)
        elif stock_id:
            data = query_broker_trading(stock_id=stock_id, limit=500)
        return render_template("broker.html", data=data, dates=dates,
                               stock_id=stock_id, selected_date=date)

    @app.route("/daily")
    def daily_page():
        date = request.args.get("date", "")
        dates = get_available_dates()
        data = []
        if date:
            data = query_daily_price(date=date, limit=2000)
        elif dates:
            date = dates[0]
            data = query_daily_price(date=date, limit=2000)
        return render_template("daily.html", data=data, dates=dates, selected_date=date)

    @app.route("/log")
    def log_page():
        logs = query_fetch_log(limit=100)
        return render_template("log.html", logs=logs)

    # ===== API 路由 =====

    @app.route("/api/stats")
    def api_stats():
        return jsonify(get_db_stats())

    @app.route("/api/stock/<stock_id>/price")
    def api_stock_price(stock_id):
        days = request.args.get("days", 60, type=int)
        data = query_daily_price(stock_id=stock_id, limit=days)
        return jsonify(data)

    @app.route("/api/stock/<stock_id>/institutional")
    def api_stock_institutional(stock_id):
        days = request.args.get("days", 60, type=int)
        data = query_institutional(stock_id=stock_id, limit=days)
        return jsonify(data)

    @app.route("/api/stock/<stock_id>/broker")
    def api_stock_broker(stock_id):
        date = request.args.get("date", "")
        if date:
            data = query_broker_trading(stock_id=stock_id, date=date, limit=500)
        else:
            data = query_broker_trading(stock_id=stock_id, limit=500)
        return jsonify(data)

    @app.route("/api/search")
    def api_search():
        q = request.args.get("q", "").strip()
        if not q:
            return jsonify([])
        stocks = query_stock_list()
        results = [s for s in stocks if q in s['stock_id'] or q in s['name']]
        return jsonify(results[:20])

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=5000, debug=True)
