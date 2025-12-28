# Trading Bot Lab

Automated backtesting system for MetaTrader 5 algorithmic trading strategies.

## What This Does

- Automatically compiles and tests trading strategies (Expert Advisors) in MT5
- Generates detailed JSON reports with trade-by-trade data
- Creates equity curve charts showing strategy performance
- Calculates key metrics: win rate, profit factor, drawdown, etc.

## Requirements

- Windows 10/11
- Python 3.8+
- MetaTrader 5 (portable installation)

## Installation

### 1. Install MT5 Portable

Download and install MT5:

```powershell
# Download installer
$url = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
Invoke-WebRequest -Uri $url -OutFile "mt5setup.exe"

# Run installer
.\mt5setup.exe
```

**Important**:
- During installation, select a custom folder inside this project directory (we use `mt5` but you can choose any name)
- Do NOT install in `Program Files`

After installation:

**Activate portable mode** (run this once to create the MQL5 folder structure):
```powershell
.\mt5\terminal64.exe /portable
```
Replace `mt5` with your chosen folder name if different.

The `/portable` flag creates the `MQL5` folder and makes MT5 store all data in the installation folder instead of `AppData`. This keeps everything self-contained in the project.

**Note**: Always launch MT5 with the `/portable` flag to ensure it uses the custom folder instead of system directories.

### 2. Install Python Dependencies

```powershell
pip install pandas matplotlib
```

## Usage

### Configure Backtest

Edit `scripts/run_backtest.py` - change these variables:

```python
# Backtest period
DATE_FROM = "2020.01.01"
DATE_TO = "2025.11.01"

# Trading parameters
SYMBOL = "USDJPY..."      # Add ... after symbol name
PERIOD = "H4"             # H1, H4, D1, etc.
DEPOSIT = 10000
LEVERAGE = 100

# System path (only if MetaEditor is in a different location)
METAEDITOR_PATH = r"C:\Program Files\MetaTrader 5\metaeditor64.exe"
```

### Run Backtest

```powershell
python scripts/run_backtest.py
```

The script will:
1. Clear MT5 cache
2. Compile the EA
3. Launch MT5 and run the backtest
4. Copy results to `reports/` folder
5. Generate equity curve chart
6. Display summary statistics

**Important**: MT5 will stay open after the backtest completes so you can review results. Close it manually when done.

If you want MT5 to close automatically, edit the config section in `scripts/run_backtest.py` and uncomment line 71:

```python
# Change this:
;ShutdownTerminal=1

# To this:
ShutdownTerminal=1
```

### View Results

After the backtest completes:
- **JSON files**: `reports/backtest_YYYYMMDD_HHMMSS.json` - Detailed trade data
- **Charts**: `reports/backtest_YYYYMMDD_HHMMSS_equity_curve.png` - Visual equity curve
- **Console**: Summary statistics printed in terminal

## Trading Strategy

The included EA (`a4n_bot_v2.mq5`) implements:

**Entry**: Asian session range breakout + EMA trend filter
- Buys when price breaks above Asian session high AND price > EMA(50)
- Sells when price breaks below Asian session low AND price < EMA(50)

**Risk Management**:
- 2% risk per trade
- Stop Loss: 1.85× ATR
- Take Profit: 3× ATR (2:1 reward/risk ratio)
- Breakeven: Moves SL to entry after 1× ATR profit
- Max 1 trade per day

**Filters**:
- ATR volatility filter (60-100% of average)
- Distance from EMA filter (max 5× ATR)
- Drawdown protection with cooldown periods
- Trailing drawdown with reduced risk mode

## Customization

### Modify Strategy Parameters

Edit `mt5/MQL5/Experts/a4n_bot_v2.mq5`:

```mql5
input int         EMA_Period = 50;
input int         ATR_Period = 28;
input double      RiskPercent = 2.0;
input double      SL_ATR_Multiplier = 1.85;
input double      TP_ATR_Multiplier = 3.0;
input int         MaxTradesPerDay = 1;
```

The script will automatically recompile the EA on the next run.

## Troubleshooting

**MetaEditor not found**:
Update `METAEDITOR_PATH` in `scripts/run_backtest.py` to match your installation.

**No historical data**:
Open MT5 → F2 → Select symbol → Download data for your timeframe.

**Cache issues**:
The script clears cache automatically. If problems persist, delete `mt5/Tester/` manually.

## File Structure

```
trading-bot-lab/
├── mt5/MQL5/Experts/
│   └── a4n_bot_v2.mq5          # Trading strategy source code
├── scripts/
│   └── run_backtest.py          # Backtest automation script
├── reports/                     # Generated results (git-ignored)
├── configs/                     # Generated configs (git-ignored)
└── logs/                        # Compilation logs (git-ignored)
```

## Disclaimer

Educational and testing purposes only. Not financial advice. Trading carries risk. Past performance does not guarantee future results. Use at your own risk.
