import os
import subprocess
import glob
from datetime import datetime
import pandas as pd
import sys
import json
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

# Fix encoding for Windows console
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')

# ==============================
# CONFIGURACIÓN
# ==============================
MT5_PATH = r"C:\Users\adri-\Desktop\code\trading-bot-lab\mt5\terminal64.exe"
EA_NAME = "a4n_bot_v2.ex5"

BASE_DIR = r"C:\Users\adri-\Desktop\code\trading-bot-lab"
CONFIG_DIR = os.path.join(BASE_DIR, "configs")
REPORT_DIR = os.path.join(BASE_DIR, "reports")
TESTER_CACHE_DIR = os.path.join(BASE_DIR, "mt5", "Tester", "cache")

os.makedirs(CONFIG_DIR, exist_ok=True)
os.makedirs(REPORT_DIR, exist_ok=True)

SYMBOL = "USDJPY..."
PERIOD = "H4"
DATE_FROM = "2020.01.01"
DATE_TO = "2025.11.01"


# ==============================
# CREAR ARCHIVO DE CONFIG
# ==============================
def create_config_file(symbol, period, date_from, date_to, ea_name, report_path):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    config_path = os.path.join(CONFIG_DIR, f"backtest_{timestamp}.ini")

    config_content = f"""
[Tester]
Expert="{ea_name}"
Symbol={symbol}
Period={period}
Model=0
Optimization=0
FromDate={date_from}
ToDate={date_to}
ForwardMode=0
Deposit=10000
Leverage=100
ExecutionMode=0
Report="{report_path}"
ReplaceReport=1
;ShutdownTerminal=1
Visual=0
"""

    with open(config_path, "w", encoding="utf-8") as f:
        f.write(config_content.strip())

    return config_path

# ==============================
# LIMPIAR CACHE MT5
# ==============================
def clear_mt5_cache():
    """Limpia cache del Tester antes de ejecutar backtest"""
    print("🧹 Limpiando cache del Tester...")

    cache_patterns = [
        # Cache del Tester (.tst files)
        os.path.join(BASE_DIR, "mt5", "Tester", "cache", "*.tst"),

        # Perfiles del Strategy Tester
        os.path.join(BASE_DIR, "mt5", "MQL5", "Profiles", "Tester", "a4n_bot*"),

        # JSONs de resultados anteriores
        os.path.join(BASE_DIR, "mt5", "Tester", "Agent-*", "MQL5", "Files", "*.json"),
    ]

    files_deleted = 0
    for pattern in cache_patterns:
        files = glob.glob(pattern, recursive=True)
        for file_path in files:
            try:
                if os.path.isfile(file_path):
                    os.remove(file_path)
                    files_deleted += 1
                elif os.path.isdir(file_path):
                    import shutil
                    shutil.rmtree(file_path)
                    files_deleted += 1
            except Exception as e:
                print(f"⚠️ No se pudo eliminar {file_path}: {e}")

    if files_deleted > 0:
        print(f"✅ Cache limpiado ({files_deleted} elementos eliminados)")
    else:
        print("✅ Cache ya estaba limpio")

# ==============================
# COMPILAR EA ANTES DE BACKTEST
# ==============================
def compile_ea():
    """Compila el EA antes de ejecutar el backtest"""
    print("🔨 Compilando EA...")

    # Eliminar .ex5 anterior para forzar recompilación limpia
    ea_source = os.path.join(BASE_DIR, "mt5", "MQL5", "Experts", "a4n_bot_v2.mq5")
    ex5_path = ea_source.replace(".mq5", ".ex5")

    if os.path.exists(ex5_path):
        os.remove(ex5_path)
        print("🗑️ Eliminado .ex5 anterior")

    metaeditor_path = r"C:\Program Files\MetaTrader 5\metaeditor64.exe"
    log_path = os.path.join(BASE_DIR, "logs", f"compile_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
    os.makedirs(os.path.dirname(log_path), exist_ok=True)

    cmd = [metaeditor_path, f"/compile:{ea_source}", f"/log:{log_path}"]
    subprocess.run(cmd, capture_output=True)

    if os.path.exists(ex5_path):
        print("✅ Compilación exitosa")
        return True
    else:
        print("❌ Error en compilación - revisa el log")
        if os.path.exists(log_path):
            with open(log_path, 'r', encoding='utf-16-le', errors='ignore') as f:
                print(f.read())
        return False

# ==============================
# EJECUTAR BACKTEST
# ==============================
def run_backtest():
    print("🧩 Preparando backtest...")

    # 1. Limpiar cache primero
    clear_mt5_cache()

    # 2. Compilar EA
    if not compile_ea():
        print("⚠️ No se pudo compilar el EA. Abortando backtest.")
        return

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    report_path = os.path.join(REPORT_DIR, f"report_{timestamp}.xml")
    config_path = create_config_file(SYMBOL, PERIOD, DATE_FROM, DATE_TO, EA_NAME, report_path)

    print(f"📄 Config guardado en: {config_path}")

    cmd = [
        MT5_PATH,
        "/portable",
        f"/config:{config_path}"
    ]

    print("🚀 Lanzando MT5 con configuración automática...")
    subprocess.run(cmd)
    print("✅ Backtest completado.")


# ==============================
# GENERAR GRÁFICO DE EQUITY CURVE
# ==============================
def generate_equity_chart(json_path):
    """Genera un gráfico PNG de la equity curve"""
    try:
        # Leer JSON con múltiples encodings
        data = None
        for encoding in ['utf-16-le', 'utf-8-sig', 'utf-8', 'utf-16']:
            try:
                with open(json_path, 'r', encoding=encoding) as f:
                    content = f.read()
                    content = content.replace('\x00', '').replace('\ufeff', '')
                    data = json.loads(content)
                break
            except:
                continue

        if not data or not data.get('trades'):
            print("⚠️ No hay datos de trades para generar gráfico")
            return

        # Preparar datos
        trades = data['trades']
        initial_balance = data['results']['balance']['initial']

        # Función para parsear fechas con múltiples formatos
        def parse_datetime(date_str):
            formats = [
                "%Y-%m-%dT%H:%M:%S",      # ISO format
                "%Y.%m.%d %H:%M:%S",      # MT5 format
                "%Y-%m-%d %H:%M:%S",      # Standard format
            ]
            for fmt in formats:
                try:
                    return datetime.strptime(date_str, fmt)
                except ValueError:
                    continue
            raise ValueError(f"No se pudo parsear la fecha: {date_str}")

        # Fecha inicial del test
        test_start = parse_datetime(data['metadata']['test_start'])

        # Crear listas para el gráfico
        dates = [test_start]
        equity = [initial_balance]

        # Calcular equity acumulada
        cumulative_profit = 0
        for trade in trades:
            cumulative_profit += trade['profit']
            equity.append(initial_balance + cumulative_profit)
            # Convertir timestamp a datetime
            close_time = parse_datetime(trade['close_time'])
            dates.append(close_time)

        # Crear el gráfico
        plt.figure(figsize=(14, 8))
        plt.style.use('seaborn-v0_8-darkgrid')

        # Plot principal
        plt.plot(dates, equity, linewidth=2, color='#2E86AB', label='Equity')

        # Línea de balance inicial
        plt.axhline(y=initial_balance, color='gray', linestyle='--',
                   linewidth=1, alpha=0.5, label=f'Balance Inicial (${initial_balance:,.0f})')

        # Área bajo la curva (verde si ganancia, rojo si pérdida)
        final_equity = equity[-1]
        fill_color = '#06D6A0' if final_equity >= initial_balance else '#EF476F'
        plt.fill_between(dates, equity, initial_balance, alpha=0.2, color=fill_color)

        # Información en el gráfico
        max_equity = max(equity)
        min_equity = min(equity)
        max_dd = data['results']['drawdown']['max_percent']
        profit_factor = data['results']['statistics']['profit_factor']
        win_rate = data['results']['statistics']['win_rate']
        total_trades = data['results']['trades']['total']
        net_profit = data['results']['profit']['net']
        net_percent = data['results']['profit']['net_percent']

        # Título
        ea_name = data['metadata']['ea_name']
        symbol = data['metadata']['symbol']
        timeframe = data['metadata']['timeframe']
        plt.title(f'{ea_name} - {symbol} {timeframe}\nEquity Curve',
                 fontsize=16, fontweight='bold', pad=20)

        # Labels
        plt.xlabel('Fecha', fontsize=12, fontweight='bold')
        plt.ylabel('Balance ($)', fontsize=12, fontweight='bold')

        # Formato de eje Y con separador de miles
        ax = plt.gca()
        ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'${x:,.0f}'))

        # Formato de eje X con fechas
        ax.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m'))
        ax.xaxis.set_major_locator(mdates.MonthLocator(interval=3))
        plt.xticks(rotation=45, ha='right')

        # Textbox con estadísticas
        stats_text = f'Balance Final: ${final_equity:,.2f}\n'
        stats_text += f'Net Profit: ${net_profit:,.2f} ({net_percent:.2f}%)\n'
        stats_text += f'Max DD: {max_dd:.2f}%\n'
        stats_text += f'Win Rate: {win_rate:.2f}%\n'
        stats_text += f'Profit Factor: {profit_factor:.2f}\n'
        stats_text += f'Total Trades: {total_trades}'

        # Posicionar el textbox
        props = dict(boxstyle='round', facecolor='white', alpha=0.9, edgecolor='gray')
        plt.text(0.02, 0.98, stats_text, transform=ax.transAxes, fontsize=10,
                verticalalignment='top', bbox=props, family='monospace')

        # Grid
        plt.grid(True, alpha=0.3, linestyle='--', linewidth=0.5)

        # Legend
        plt.legend(loc='upper left', fontsize=10, bbox_to_anchor=(0.02, 0.85))

        # Ajustar layout
        plt.tight_layout()

        # Guardar
        chart_filename = os.path.basename(json_path).replace('.json', '_equity_curve.png')
        chart_path = os.path.join(REPORT_DIR, chart_filename)
        plt.savefig(chart_path, dpi=150, bbox_inches='tight', facecolor='white')
        plt.close()

        print(f"📊 Gráfico generado: {chart_path}")

    except Exception as e:
        print(f"⚠️ Error al generar gráfico: {e}")
        import traceback
        traceback.print_exc()

# ==============================
# COPIAR JSON A REPORTS
# ==============================
def copy_json_to_reports():
    """Busca y copia el archivo JSON más reciente a la carpeta reports"""
    agent_files_dir = os.path.join(BASE_DIR, "mt5", "Tester", "Agent-127.0.0.1-3000", "MQL5", "Files")

    if not os.path.exists(agent_files_dir):
        print("⚠️ No se encontró el directorio de archivos del agente")
        return

    # Buscar archivos JSON
    json_files = glob.glob(os.path.join(agent_files_dir, "backtest_*.json"))

    if not json_files:
        print("⚠️ No se encontraron archivos JSON generados")
        return

    # Obtener el más reciente
    json_files.sort(key=os.path.getmtime, reverse=True)
    latest_json = json_files[0]

    # Copiar a reports
    import shutil
    dest_path = os.path.join(REPORT_DIR, os.path.basename(latest_json))
    shutil.copy2(latest_json, dest_path)

    print(f"📊 Archivo JSON copiado a: {dest_path}")

    # Generar gráfico de equity curve
    generate_equity_chart(dest_path)

    # Mostrar estadísticas básicas
    try:
        # Intentar múltiples codificaciones
        for encoding in ['utf-16-le', 'utf-8-sig', 'utf-8', 'utf-16']:
            try:
                with open(dest_path, 'r', encoding=encoding) as f:
                    data = json.load(f)
                break
            except:
                continue

        print("\n" + "="*50)
        print("📈 RESUMEN DEL BACKTEST")
        print("="*50)
        print(f"EA: {data['metadata']['ea_name']} v{data['metadata']['ea_version']}")
        print(f"Símbolo: {data['metadata']['symbol']}")
        print(f"Periodo: {data['metadata']['timeframe']}")
        print(f"\nBalance Inicial: ${data['results']['balance']['initial']:.2f}")
        print(f"Balance Final: ${data['results']['balance']['final']:.2f}")
        print(f"Profit Neto: ${data['results']['profit']['net']:.2f} ({data['results']['profit']['net_percent']:.2f}%)")

        # Calcular CAGR para Calmar Ratio
        try:
            date_start = datetime.strptime(data['metadata']['test_start'], "%Y-%m-%dT%H:%M:%S")
            date_end = datetime.strptime(data['metadata']['test_end'], "%Y-%m-%dT%H:%M:%S")
            duration_years = (date_end - date_start).days / 365.25
            balance_initial = data['results']['balance']['initial']
            balance_final = data['results']['balance']['final']
            cagr = ((balance_final / balance_initial) ** (1 / duration_years) - 1) * 100
        except:
            cagr = None

        # Drawdown: mostrar ambos métodos
        max_dd_equity = data['results']['drawdown']['max_percent']
        print(f"\nMax Drawdown (Equity): {max_dd_equity:.2f}%")

        # Relative DD (puede no existir en JSONs antiguos)
        if 'max_relative_percent' in data['results']['drawdown']:
            rel_dd = data['results']['drawdown']['max_relative_percent']
            print(f"Max Drawdown (Relative): {rel_dd:.2f}%")
        else:
            print(f"Max Drawdown (Relative): N/A")

        # Calmar Ratio (con equity DD)
        if cagr is not None and max_dd_equity > 0:
            calmar_ratio = cagr / max_dd_equity
            print(f"\nCalmar Ratio: {calmar_ratio:.2f}")

        print(f"\nTrades Totales: {data['results']['trades']['total']}")
        print(f"Ganadores: {data['results']['trades']['winning']} ({data['results']['statistics']['win_rate']:.2f}%)")
        print(f"Perdedores: {data['results']['trades']['losing']}")
        print(f"Profit Factor: {data['results']['statistics']['profit_factor']:.2f}")
        print(f"Avg Trade: ${data['results']['statistics']['avg_trade']:.2f}")
        print("="*50 + "\n")
    except Exception as e:
        print(f"⚠️ No se pudo parsear el JSON: {e}")


# ==============================
# MAIN
# ==============================
if __name__ == "__main__":
    run_backtest()
    copy_json_to_reports()
