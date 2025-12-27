# Trading Bot Lab

Automated trading system for MetaTrader 5 with comprehensive backtesting framework for algorithmic trading strategies on forex and CFD markets.

## Overview

This project implements an automated trading strategy based on EMA breakouts with ATR-based risk management. The system includes automated backtesting, Python automation scripts, comprehensive logging with JSON export, visual equity curve generation, and advanced risk management with drawdown protection.

## Features

- Asian Session Range Breakout Strategy
- ATR-Based Dynamic Risk Management
- Drawdown Protection with automatic cooldown periods
- Automated Backtesting Pipeline with one-command execution
- Result Analysis Tools with JSON export and equity curves
- Clean Cache Management for accurate backtest results

## Prerequisites

- Windows 10/11 (64-bit)
- Python 3.8 or higher
- MetaTrader 5 (portable installation)
- PowerShell 5.1 or higher

## Installation

### 1. Install MT5 Portable

Download the MT5 installer:

```powershell
$url = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
Invoke-WebRequest -Uri $url -OutFile "mt5setup.exe"
```

Install MT5 in portable mode to the project directory:

```powershell
.\mt5setup.exe /portable /PATH:"C:\Users\<username>\Desktop\code\trading-bot-lab\mt5"
```

Verify installation:

```powershell
Test-Path ".\mt5\terminal64.exe"
```

Launch MT5 for first-time setup:

```powershell
.\mt5\terminal64.exe /portable
```

Download historical data:
- Press F2 to open History Center
- Select your symbol (e.g., USDJPY)
- Download H4 timeframe data

### 2. Set Up Python Environment

Clone the repository:

```powershell
git clone <repository-url>
cd trading-bot-lab
```

Create and activate virtual environment:

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
```

Install dependencies:

```powershell
pip install -r requirements.txt
```

## Project Structure

```
trading-bot-lab/
├── mt5/MQL5/Experts/
│   └── a4n_bot_v2.mq5          # Trading bot source code
├── scripts/
│   └── run_backtest.py          # Main backtest automation script
├── configs/                     # Generated config files (git-ignored)
├── reports/                     # Generated reports (git-ignored)
├── logs/                        # Compilation logs (git-ignored)
└── requirements.txt
```

## Usage

### Running Backtests

Configure backtest parameters in `scripts/run_backtest.py`:

```python
SYMBOL = "USDJPY..."
PERIOD = "H4"
DATE_FROM = "2020.01.01"
DATE_TO = "2025.11.01"
```

Execute backtest:

```powershell
python scripts/run_backtest.py
```

The script performs the following operations:
1. Cleans MT5 cache
2. Compiles the EA
3. Launches MT5 with test configuration
4. Copies results to reports directory
5. Generates equity curve chart
6. Displays summary statistics

### Analyzing Results

Reports are generated in the `reports/` directory:

- JSON files contain detailed trade-by-trade data
- PNG files show visual equity curves
- Console output displays summary statistics

## Trading Strategy

### Entry Rules

1. Asian Session Range Detection (23:00-07:00 server time)
2. Breakout Signal:
   - LONG: Price breaks above Asian high AND price > EMA(50)
   - SHORT: Price breaks below Asian low AND price < EMA(50)
3. ATR Filter: ATR within 60-100% of average
4. Distance Filter: Price within 5x ATR from EMA

### Risk Management

- Position Sizing: 2% risk per trade
- Stop Loss: 1.85x ATR from entry
- Take Profit: 3x ATR from entry (2:1 reward/risk ratio)
- Breakeven: Moves SL to entry after 1x ATR profit

### Protection Mechanisms

Drawdown Protection:
- Monitors last 31 trades
- Triggers 65-day cooldown if drawdown exceeds 2%

Trailing Drawdown:
- Tracks equity peak
- Reduces risk to 1.25% when drawdown exceeds 1%
- Applies stricter filters during recovery

### Key Parameters

```mql5
input int         EMA_Period = 50;
input int         ATR_Period = 28;
input double      RiskPercent = 2.0;
input double      SL_ATR_Multiplier = 1.85;
input double      TP_ATR_Multiplier = 3.0;
input int         MaxTradesPerDay = 1;
```

## Configuration

### Modifying EA Parameters

Edit `mt5/MQL5/Experts/a4n_bot_v2.mq5` and the script will automatically recompile it on the next backtest run.

### Backtest Settings

Edit `scripts/run_backtest.py`:

```python
DATE_FROM = "2020.01.01"
DATE_TO = "2025.11.01"
Deposit = 10000
Leverage = 100
```

## Performance Metrics

The system tracks and exports:

- Trade Statistics: Win rate, profit factor, average trade
- Risk Metrics: Maximum drawdown (equity and relative), Calmar ratio
- Equity Tracking: Balance peaks and drawdown periods
- Time Analysis: Trade duration, session performance

## Troubleshooting

### MetaEditor Not Found

If the compilation script cannot find MetaEditor, update the path in `scripts/run_backtest.py`:

```python
metaeditor_path = r"C:\Program Files\MetaTrader 5\metaeditor64.exe"
```

### Cache Issues

The backtest script automatically clears cache before each run. If you still experience issues, delete the `mt5/Tester/` directory manually.

### Historical Data Missing

Ensure historical data is downloaded in MT5:
1. Open MT5 terminal
2. Press F2 (History Center)
3. Select symbol and timeframe
4. Click "Download"

## Disclaimer

This software is for educational and testing purposes only. It is not intended for live trading without thorough testing and understanding of risks. Trading financial instruments carries high risk and may not be suitable for all investors. Past performance does not guarantee future results. The authors are not responsible for any financial losses.

USE AT YOUR OWN RISK.

## Contributing

Contributions are welcome. Please fork the repository, create a feature branch, test changes with backtests, and submit a pull request.

## Contact

For questions or support, please open an issue on GitHub.
