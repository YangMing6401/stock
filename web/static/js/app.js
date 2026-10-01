/**
 * 台股數據追蹤系統 - 前端 JavaScript
 */

// ===== 股票搜尋 =====
document.addEventListener('DOMContentLoaded', () => {
    const searchInput = document.getElementById('stock-search');
    const searchResults = document.getElementById('search-results');
    let searchTimeout = null;

    if (searchInput && searchResults) {
        searchInput.addEventListener('input', (e) => {
            const query = e.target.value.trim();
            clearTimeout(searchTimeout);

            if (query.length < 1) {
                searchResults.classList.remove('show');
                return;
            }

            searchTimeout = setTimeout(async () => {
                try {
                    const resp = await fetch(`/api/search?q=${encodeURIComponent(query)}`);
                    const data = await resp.json();

                    if (data.length === 0) {
                        searchResults.innerHTML = '<div class="result-item"><span class="result-name" style="color:var(--text-muted)">找不到符合的股票</span></div>';
                    } else {
                        searchResults.innerHTML = data.map(s => `
                            <div class="result-item" onclick="window.location.href='/stock/${s.stock_id}'">
                                <span class="result-id">${s.stock_id}</span>
                                <span class="result-name">${s.name}</span>
                                <span class="result-market">${s.market}</span>
                            </div>
                        `).join('');
                    }
                    searchResults.classList.add('show');
                } catch (err) {
                    console.error('搜尋失敗:', err);
                }
            }, 300);
        });

        // 點擊外部關閉搜尋結果
        document.addEventListener('click', (e) => {
            if (!searchInput.contains(e.target) && !searchResults.contains(e.target)) {
                searchResults.classList.remove('show');
            }
        });

        // Enter 鍵搜尋
        searchInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                const query = searchInput.value.trim();
                if (/^\d{4,6}$/.test(query)) {
                    window.location.href = `/stock/${query}`;
                }
            }
        });
    }
});


// ===== 數字格式化 =====
function formatNumber(num) {
    if (num === null || num === undefined) return '--';
    return Number(num).toLocaleString('zh-TW');
}

function formatMoney(num) {
    if (num === null || num === undefined) return '--';
    const abs = Math.abs(num);
    if (abs >= 1e8) return (num / 1e8).toFixed(2) + ' 億';
    if (abs >= 1e4) return (num / 1e4).toFixed(0) + ' 萬';
    return Number(num).toLocaleString('zh-TW');
}

function formatVolume(num) {
    if (num === null || num === undefined) return '--';
    // 股數轉張數 (1張 = 1000股)
    const zhang = num / 1000;
    if (zhang >= 10000) return (zhang / 10000).toFixed(1) + ' 萬張';
    return formatNumber(Math.round(zhang)) + ' 張';
}


// ===== 漲跌 CSS class =====
function changeClass(val) {
    if (val > 0) return 'up';
    if (val < 0) return 'down';
    return 'neutral';
}

function changePrefix(val) {
    if (val > 0) return '+';
    return '';
}


// ===== Chart.js 圖表工具 =====

/**
 * 建立股價走勢圖
 */
function createPriceChart(canvasId, labels, prices, volumes) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return;

    // 反轉資料（API 回傳是由新到舊）
    const revLabels = [...labels].reverse();
    const revPrices = [...prices].reverse();
    const revVolumes = volumes ? [...volumes].reverse() : null;

    const datasets = [{
        label: '收盤價',
        data: revPrices,
        borderColor: '#3b82f6',
        backgroundColor: 'rgba(59, 130, 246, 0.08)',
        fill: true,
        tension: 0.3,
        pointRadius: 1.5,
        pointHoverRadius: 5,
        borderWidth: 2,
        yAxisID: 'y'
    }];

    if (revVolumes) {
        datasets.push({
            label: '成交量（張）',
            data: revVolumes.map(v => v ? Math.round(v / 1000) : 0),
            type: 'bar',
            backgroundColor: 'rgba(139, 92, 246, 0.25)',
            borderColor: 'rgba(139, 92, 246, 0.4)',
            borderWidth: 1,
            yAxisID: 'y1'
        });
    }

    new Chart(ctx, {
        type: 'line',
        data: { labels: revLabels, datasets },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: { mode: 'index', intersect: false },
            plugins: {
                legend: {
                    labels: { color: '#94a3b8', font: { size: 12 } }
                },
                tooltip: {
                    backgroundColor: 'rgba(17, 24, 39, 0.95)',
                    titleColor: '#f1f5f9',
                    bodyColor: '#94a3b8',
                    borderColor: 'rgba(255,255,255,0.08)',
                    borderWidth: 1,
                    cornerRadius: 8,
                    padding: 12
                }
            },
            scales: {
                x: {
                    ticks: { color: '#64748b', maxTicksLimit: 10, font: { size: 11 } },
                    grid: { color: 'rgba(255,255,255,0.04)' }
                },
                y: {
                    position: 'left',
                    ticks: { color: '#64748b', font: { size: 11 } },
                    grid: { color: 'rgba(255,255,255,0.04)' }
                },
                y1: {
                    position: 'right',
                    ticks: { color: '#64748b', font: { size: 11 } },
                    grid: { display: false },
                    display: !!revVolumes
                }
            }
        }
    });
}


/**
 * 建立法人買賣超柱狀圖
 */
function createInstitutionalChart(canvasId, labels, foreignNet, trustNet, dealerNet) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return;

    const revLabels = [...labels].reverse();
    const revForeign = [...foreignNet].reverse();
    const revTrust = [...trustNet].reverse();
    const revDealer = [...dealerNet].reverse();

    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: revLabels,
            datasets: [
                {
                    label: '外資',
                    data: revForeign.map(v => v ? Math.round(v / 1000) : 0),
                    backgroundColor: revForeign.map(v => v >= 0 ? 'rgba(239, 68, 68, 0.6)' : 'rgba(16, 185, 129, 0.6)'),
                    borderRadius: 3
                },
                {
                    label: '投信',
                    data: revTrust.map(v => v ? Math.round(v / 1000) : 0),
                    backgroundColor: revTrust.map(v => v >= 0 ? 'rgba(245, 158, 11, 0.6)' : 'rgba(6, 182, 212, 0.6)'),
                    borderRadius: 3
                },
                {
                    label: '自營商',
                    data: revDealer.map(v => v ? Math.round(v / 1000) : 0),
                    backgroundColor: revDealer.map(v => v >= 0 ? 'rgba(236, 72, 153, 0.6)' : 'rgba(139, 92, 246, 0.6)'),
                    borderRadius: 3
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: { mode: 'index', intersect: false },
            plugins: {
                legend: {
                    labels: { color: '#94a3b8', font: { size: 12 } }
                },
                tooltip: {
                    backgroundColor: 'rgba(17, 24, 39, 0.95)',
                    titleColor: '#f1f5f9',
                    bodyColor: '#94a3b8',
                    borderColor: 'rgba(255,255,255,0.08)',
                    borderWidth: 1,
                    cornerRadius: 8,
                    callbacks: {
                        label: function (ctx) {
                            return ctx.dataset.label + ': ' + formatNumber(ctx.raw) + ' 張';
                        }
                    }
                }
            },
            scales: {
                x: {
                    ticks: { color: '#64748b', maxTicksLimit: 10, font: { size: 11 } },
                    grid: { color: 'rgba(255,255,255,0.04)' }
                },
                y: {
                    ticks: {
                        color: '#64748b',
                        font: { size: 11 },
                        callback: v => formatNumber(v) + ' 張'
                    },
                    grid: { color: 'rgba(255,255,255,0.04)' }
                }
            }
        }
    });
}


// ===== 日期選擇器變更 =====
function onDateChange(selectEl, baseUrl) {
    const date = selectEl.value;
    if (date) {
        window.location.href = `${baseUrl}?date=${date}`;
    }
}

// ===== 表格排序 =====
function sortTable(tableId, colIdx, isNumeric) {
    const table = document.getElementById(tableId);
    if (!table) return;

    const tbody = table.querySelector('tbody');
    const rows = Array.from(tbody.querySelectorAll('tr'));

    // 判斷排序方向
    const currentDir = table.getAttribute('data-sort-dir') === 'asc' ? 'desc' : 'asc';
    table.setAttribute('data-sort-dir', currentDir);
    table.setAttribute('data-sort-col', colIdx);

    rows.sort((a, b) => {
        let aVal = a.cells[colIdx]?.textContent?.trim() || '';
        let bVal = b.cells[colIdx]?.textContent?.trim() || '';

        if (isNumeric) {
            aVal = parseFloat(aVal.replace(/[,+%張億萬]/g, '')) || 0;
            bVal = parseFloat(bVal.replace(/[,+%張億萬]/g, '')) || 0;
        }

        let result;
        if (isNumeric) {
            result = aVal - bVal;
        } else {
            result = aVal.localeCompare(bVal, 'zh-TW');
        }

        return currentDir === 'asc' ? result : -result;
    });

    rows.forEach(row => tbody.appendChild(row));
}
