#property copyright "Trading Bot Lab"
#property version   "1.00"
#property strict

#include <BacktestLoggerAuto.mqh>

#define ASIAN_SESSION_START 23
#define ASIAN_SESSION_END 7

input group "=== General Settings ==="
input int         MagicNumber = 100001;
input string      TradeComment = "USDJPY_EMA_ATR";

input group "=== Indicator Settings ==="
input int         EMA_Period = 50;
input int         ATR_Period = 28;

input group "=== Risk Management ==="
input double      RiskPercent = 2.0;
input double      SL_ATR_Multiplier = 1.85;
input double      TP_ATR_Multiplier = 3;
input double      BE_ATR_Multiplier = 1;

input group "=== Trade Limits ==="
input int         MaxTradesPerDay = 1;

input group "=== Filters ==="
input bool        OnlyLongs = true;

input group "=== ATR Filter ==="
input bool        EnableATRFilter = true;
input double      MinATRPercent = 60.0;
input double      MaxATRPercent = 100.0;
input int         ATRLookbackPeriods = 50;

input group "=== Distance Filter ==="
input bool        EnableDistanceFilter = true;
input double      MaxDistanceFromEMA_ATR = 5;

input group "=== Drawdown Protection ==="
input int         DrawdownLookbackTrades = 31;
input double      MaxDrawdownPercent = 2.0;
input int         CooldownDays = 65;

input group "=== Trailing Drawdown Protection ==="
input bool        EnableTrailingDD = true;
input double      MaxTrailingDDPercent = 1.0;
input double      ReducedRiskPercent = 1.25;
input double      TrailingDDRecoveryPercent = 7;

input group "=== Strict Filters (When Trailing DD Active) ==="
input double      StrictMinATRPercent = 75.0;
input double      StrictMaxDistanceFromEMA_ATR = 5;

CBacktestLoggerAuto* g_logger = NULL;

class IIndicator
{
public:
    virtual double GetValue(int shift = 0) = 0;
    virtual bool IsValid() = 0;
};

class EMAIndicator : public IIndicator
{
private:
    int m_handle;
    int m_period;
    double m_buffer[];

public:
    EMAIndicator(int period)
    {
        m_period = period;
        m_handle = iMA(_Symbol, PERIOD_CURRENT, m_period, 0, MODE_EMA, PRICE_CLOSE);
        ArraySetAsSeries(m_buffer, true);
    }

    ~EMAIndicator()
    {
        if(m_handle != INVALID_HANDLE)
            IndicatorRelease(m_handle);
    }

    virtual double GetValue(int shift = 0) override
    {
        if(CopyBuffer(m_handle, 0, shift, 1, m_buffer) <= 0)
            return 0;
        return m_buffer[0];
    }

    virtual bool IsValid() override
    {
        return m_handle != INVALID_HANDLE;
    }
};

class ATRIndicator : public IIndicator
{
private:
    int m_handle;
    int m_period;
    double m_buffer[];

public:
    ATRIndicator(int period)
    {
        m_period = period;
        m_handle = iATR(_Symbol, PERIOD_CURRENT, m_period);
        ArraySetAsSeries(m_buffer, true);
    }

    ~ATRIndicator()
    {
        if(m_handle != INVALID_HANDLE)
            IndicatorRelease(m_handle);
    }

    virtual double GetValue(int shift = 0) override
    {
        if(CopyBuffer(m_handle, 0, shift, 1, m_buffer) <= 0)
            return 0;
        return m_buffer[0];
    }

    virtual bool IsValid() override
    {
        return m_handle != INVALID_HANDLE;
    }
};

class IRiskManager
{
public:
    virtual double CalculateLotSize(double slDistance) = 0;
    virtual double CalculateSL(bool isBuy, double atr) = 0;
    virtual double CalculateTP(bool isBuy, double atr) = 0;
    virtual void ManageBreakEven(double atr) = 0;
};

class ATRRiskManager : public IRiskManager
{
private:
    double m_riskPercent;
    double m_slMultiplier;
    double m_tpMultiplier;
    double m_beMultiplier;
    int m_magicNumber;

public:
    ATRRiskManager(double riskPercent, double slMult, double tpMult, double beMult, int magic)
    {
        m_riskPercent = riskPercent;
        m_slMultiplier = slMult;
        m_tpMultiplier = tpMult;
        m_beMultiplier = beMult;
        m_magicNumber = magic;
    }

    void UpdateRiskPercent(double newRiskPercent)
    {
        m_riskPercent = newRiskPercent;
    }

    virtual double CalculateLotSize(double slDistance) override
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = balance * (m_riskPercent / 100.0);

        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

        double moneyPerPoint = (tickSize != 0) ? (tickValue / tickSize) : 0;
        double lots = (moneyPerPoint != 0 && slDistance != 0) ?
                      (riskAmount / (slDistance * moneyPerPoint)) : 0;

        double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

        if(lots < minLot) lots = minLot;
        if(lots > maxLot) lots = maxLot;

        lots = MathFloor(lots / lotStep) * lotStep;
        return NormalizeDouble(lots, 2);
    }

    virtual double CalculateSL(bool isBuy, double atr) override
    {
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double sl = isBuy ? price - (atr * m_slMultiplier) : price + (atr * m_slMultiplier);
        return NormalizeDouble(sl, digits);
    }

    virtual double CalculateTP(bool isBuy, double atr) override
    {
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double tp = isBuy ? price + (atr * m_tpMultiplier) : price - (atr * m_tpMultiplier);
        return NormalizeDouble(tp, digits);
    }

    virtual void ManageBreakEven(double atr) override
    {
        double beDistance = atr * m_beMultiplier;

        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;

            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ?
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                                 SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
            double profit = isBuy ? (currentPrice - openPrice) : (openPrice - currentPrice);

            if(profit >= beDistance)
            {
                if(isBuy && (currentSL < openPrice || currentSL == 0))
                    ModifyPosition(ticket, openPrice, PositionGetDouble(POSITION_TP));
                else if(!isBuy && (currentSL > openPrice || currentSL == 0))
                    ModifyPosition(ticket, openPrice, PositionGetDouble(POSITION_TP));
            }
        }
    }

private:
    void ModifyPosition(ulong ticket, double sl, double tp)
    {
        MqlTradeRequest request = {};
        MqlTradeResult result = {};

        request.action = TRADE_ACTION_SLTP;
        request.position = ticket;
        request.sl = sl;
        request.tp = tp;
        request.symbol = _Symbol;

        OrderSend(request, result);
    }
};

class AsianSessionRange
{
private:
    double m_high;
    double m_low;
    bool m_isInSession;
    datetime m_sessionDate;

public:
    AsianSessionRange()
    {
        m_high = 0;
        m_low = DBL_MAX;
        m_isInSession = false;
        m_sessionDate = 0;
    }

    void Update()
    {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        int hour = dt.hour;
        bool inSession = (hour >= ASIAN_SESSION_START || hour < ASIAN_SESSION_END);
        datetime today = iTime(_Symbol, PERIOD_D1, 0);

        if(inSession && (today != m_sessionDate))
        {
            m_high = iHigh(_Symbol, PERIOD_CURRENT, 0);
            m_low = iLow(_Symbol, PERIOD_CURRENT, 0);
            m_sessionDate = today;
        }

        if(inSession)
        {
            double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
            double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);

            if(currentHigh > m_high) m_high = currentHigh;
            if(currentLow < m_low) m_low = currentLow;
        }

        m_isInSession = inSession;
    }

    bool IsValid() { return m_high > 0 && m_low > 0 && m_low < DBL_MAX && m_sessionDate > 0; }
    bool IsSessionActive() { return m_isInSession; }
    double GetHigh() { return m_high; }
    double GetLow() { return m_low; }
    double GetRange() { return m_high - m_low; }
};

class ISignalGenerator
{
public:
    virtual int GetSignal(bool isTrailingDDActive = false) = 0;
};

class BreakoutSignalGenerator : public ISignalGenerator
{
private:
    EMAIndicator* m_ema;
    AsianSessionRange* m_asianRange;
    ATRIndicator* m_atr;
    bool m_onlyLongs;
    bool m_enableATRFilter;
    double m_minATRPercent;
    double m_maxATRPercent;
    int m_atrLookbackPeriods;
    bool m_enableDistanceFilter;
    double m_maxDistanceFromEMA_ATR;
    double m_strictMinATRPercent;
    double m_strictMaxDistanceFromEMA_ATR;

public:
    BreakoutSignalGenerator(EMAIndicator* ema, AsianSessionRange* asianRange, ATRIndicator* atr,
                            bool onlyLongs, bool enableATRFilter, double minATRPercent,
                            double maxATRPercent, int atrLookbackPeriods,
                            bool enableDistanceFilter, double maxDistanceFromEMA_ATR,
                            double strictMinATRPercent, double strictMaxDistanceFromEMA_ATR)
    {
        m_ema = ema;
        m_asianRange = asianRange;
        m_atr = atr;
        m_onlyLongs = onlyLongs;
        m_enableATRFilter = enableATRFilter;
        m_minATRPercent = minATRPercent;
        m_maxATRPercent = maxATRPercent;
        m_atrLookbackPeriods = atrLookbackPeriods;
        m_enableDistanceFilter = enableDistanceFilter;
        m_maxDistanceFromEMA_ATR = maxDistanceFromEMA_ATR;
        m_strictMinATRPercent = strictMinATRPercent;
        m_strictMaxDistanceFromEMA_ATR = strictMaxDistanceFromEMA_ATR;
    }

    virtual int GetSignal(bool isTrailingDDActive = false) override
    {
        if(m_ema == NULL || !m_ema.IsValid())
            return 0;

        if(m_asianRange == NULL)
            return 0;

        m_asianRange.Update();

        if(m_asianRange.IsSessionActive())
            return 0;

        if(!m_asianRange.IsValid())
            return 0;

        if(m_enableATRFilter && m_atr != NULL && m_atr.IsValid())
        {
            double currentATR = m_atr.GetValue(0);
            double sumATR = 0;
            int validPeriods = 0;

            for(int i = 0; i < m_atrLookbackPeriods; i++)
            {
                double atrValue = m_atr.GetValue(i);
                if(atrValue > 0)
                {
                    sumATR += atrValue;
                    validPeriods++;
                }
            }

            if(validPeriods > 0)
            {
                double avgATR = sumATR / validPeriods;

                if(avgATR > 0)
                {
                    double atrPercent = (currentATR / avgATR) * 100.0;

                    if(atrPercent < m_minATRPercent || atrPercent > m_maxATRPercent)
                        return 0;
                }
            }
        }

        double close = iClose(_Symbol, PERIOD_CURRENT, 0);
        double ema = m_ema.GetValue(0);
        double atr = m_atr != NULL ? m_atr.GetValue(0) : 0;

        if(m_enableDistanceFilter && atr > 0)
        {
            double distance = MathAbs(close - ema);
            double distanceInATRs = distance / atr;

            if(distanceInATRs > m_maxDistanceFromEMA_ATR)
                return 0;
        }

        double asianHigh = m_asianRange.GetHigh();
        double asianLow = m_asianRange.GetLow();

        int signal = 0;

        if(close > ema && close > asianHigh)
            signal = 1;
        else if(!m_onlyLongs && close < ema && close < asianLow)
            signal = -1;

        if(signal == 0)
            return 0;

        // Apply EXTRA STRICT filters when Trailing DD is active
        if(isTrailingDDActive)
        {
            // Strict Filter 1: Only high volatility (configurable via StrictMinATRPercent)
            if(m_atr != NULL && m_atr.IsValid())
            {
                double currentATR = m_atr.GetValue(0);
                double sumATR = 0;
                int validPeriods = 0;

                for(int i = 0; i < m_atrLookbackPeriods; i++)
                {
                    double atrValue = m_atr.GetValue(i);
                    if(atrValue > 0)
                    {
                        sumATR += atrValue;
                        validPeriods++;
                    }
                }

                if(validPeriods > 0)
                {
                    double avgATR = sumATR / validPeriods;
                    if(avgATR > 0)
                    {
                        double atrPercent = (currentATR / avgATR) * 100.0;

                        if(atrPercent < m_strictMinATRPercent)
                            return 0;
                    }
                }
            }

            // Strict Filter 2: Closer to EMA (configurable via StrictMaxDistanceFromEMA_ATR)
            if(atr > 0)
            {
                double distance = MathAbs(close - ema);
                double distanceInATRs = distance / atr;

                if(distanceInATRs > m_strictMaxDistanceFromEMA_ATR)
                    return 0;
            }
        }

        return signal;
    }
};

class TradingStrategy
{
private:
    ISignalGenerator* m_signalGenerator;
    IRiskManager* m_riskManager;
    ATRIndicator* m_atr;
    int m_magicNumber;
    string m_comment;
    int m_maxTradesPerDay;
    datetime m_lastTradeDate;
    int m_todayTradeCount;

    double m_balanceHistory[];
    int m_tradeCount;
    int m_lookbackTrades;
    double m_maxDrawdownPercent;
    int m_cooldownDays;
    datetime m_cooldownEndDate;
    int m_tradesAtCooldownStart;

    double m_peakEquity;
    bool m_trailingDDActive;
    double m_originalRiskPercent;
    bool m_enableTrailingDD;
    double m_maxTrailingDDPercent;
    double m_reducedRiskPercent;
    double m_trailingDDRecoveryPercent;

public:
    TradingStrategy(ISignalGenerator* signalGen, IRiskManager* riskMgr,
                    ATRIndicator* atr, int magic, string comment, int maxTradesPerDay,
                    int lookbackTrades, double maxDrawdownPercent, int cooldownDays,
                    bool enableTrailingDD, double maxTrailingDDPercent,
                    double reducedRiskPercent, double trailingDDRecoveryPercent, double originalRiskPercent)
    {
        m_signalGenerator = signalGen;
        m_riskManager = riskMgr;
        m_atr = atr;
        m_magicNumber = magic;
        m_comment = comment;
        m_maxTradesPerDay = maxTradesPerDay;
        m_lastTradeDate = 0;
        m_todayTradeCount = 0;

        m_lookbackTrades = lookbackTrades;
        m_maxDrawdownPercent = maxDrawdownPercent;
        m_cooldownDays = cooldownDays;
        m_tradeCount = 0;
        m_cooldownEndDate = 0;
        m_tradesAtCooldownStart = 0;

        m_peakEquity = AccountInfoDouble(ACCOUNT_BALANCE);
        m_trailingDDActive = false;
        m_originalRiskPercent = originalRiskPercent;
        m_enableTrailingDD = enableTrailingDD;
        m_maxTrailingDDPercent = maxTrailingDDPercent;
        m_reducedRiskPercent = reducedRiskPercent;
        m_trailingDDRecoveryPercent = trailingDDRecoveryPercent;

        ArrayResize(m_balanceHistory, lookbackTrades);
        ArrayInitialize(m_balanceHistory, AccountInfoDouble(ACCOUNT_BALANCE));
    }

    void UpdateBalanceHistory()
    {
        double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_balanceHistory[m_tradeCount % m_lookbackTrades] = currentBalance;
        m_tradeCount++;
    }

    bool IsTrailingDDActive() { return m_trailingDDActive; }

    void Execute()
    {
        double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);

        if(currentBalance > m_peakEquity)
            m_peakEquity = currentBalance;

        if(m_enableTrailingDD)
        {
            double ddPercent = ((m_peakEquity - currentBalance) / m_peakEquity) * 100.0;

            if(!m_trailingDDActive && ddPercent >= m_maxTrailingDDPercent)
            {
                m_trailingDDActive = true;

                ATRRiskManager* atrRiskMgr = dynamic_cast<ATRRiskManager*>(m_riskManager);
                if(atrRiskMgr != NULL)
                    atrRiskMgr.UpdateRiskPercent(m_reducedRiskPercent);
            }

            if(m_trailingDDActive && ddPercent <= m_trailingDDRecoveryPercent)
            {
                m_trailingDDActive = false;

                ATRRiskManager* atrRiskMgr = dynamic_cast<ATRRiskManager*>(m_riskManager);
                if(atrRiskMgr != NULL)
                    atrRiskMgr.UpdateRiskPercent(m_originalRiskPercent);
            }
        }

        if(TimeCurrent() < m_cooldownEndDate)
            return;

        if(m_cooldownEndDate > 0 && TimeCurrent() >= m_cooldownEndDate)
        {
            m_cooldownEndDate = 0;
            ArrayInitialize(m_balanceHistory, AccountInfoDouble(ACCOUNT_BALANCE));
            m_tradeCount = 0;
        }

        if(m_tradeCount >= m_lookbackTrades && m_cooldownEndDate == 0)
        {
            double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);

            int oldestIndex = 0;
            double maxBalance = m_balanceHistory[0];
            for(int i = 1; i < m_lookbackTrades; i++)
            {
                if(m_balanceHistory[i] > maxBalance)
                    maxBalance = m_balanceHistory[i];
            }

            if(maxBalance > 0)
            {
                double drawdownPercent = ((maxBalance - currentBalance) / maxBalance) * 100.0;

                if(drawdownPercent >= m_maxDrawdownPercent)
                {
                    m_cooldownEndDate = TimeCurrent() + (m_cooldownDays * 86400);
                    m_tradesAtCooldownStart = m_tradeCount;
                    return;
                }
            }
        }

        double atr = m_atr.GetValue(0);
        if(atr <= 0)
            return;

        if(CountOpenPositions() > 0)
        {
            m_riskManager.ManageBreakEven(atr);
        }

        datetime today = iTime(_Symbol, PERIOD_D1, 0);
        if(today != m_lastTradeDate)
        {
            m_lastTradeDate = today;
            m_todayTradeCount = 0;
        }

        if(m_todayTradeCount >= m_maxTradesPerDay)
            return;

        int signal = m_signalGenerator.GetSignal(m_trailingDDActive);
        if(signal == 0)
            return;

        if(signal == 1)
        {
            CloseOppositePositions(true);
            if(CountOpenPositions() == 0)
            {
                OpenOrder(true, atr);
                m_todayTradeCount++;
            }
        }
        else if(signal == -1)
        {
            CloseOppositePositions(false);
            if(CountOpenPositions() == 0)
            {
                OpenOrder(false, atr);
                m_todayTradeCount++;
            }
        }
    }

private:
    void OpenOrder(bool isBuy, double atr)
    {
        double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double sl = m_riskManager.CalculateSL(isBuy, atr);
        double tp = m_riskManager.CalculateTP(isBuy, atr);

        double slDistance = MathAbs(price - sl);
        double lots = m_riskManager.CalculateLotSize(slDistance);

        if(lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
            return;

        MqlTradeRequest request = {};
        MqlTradeResult result = {};

        request.action = TRADE_ACTION_DEAL;
        request.symbol = _Symbol;
        request.volume = lots;
        request.type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        request.price = price;
        request.sl = sl;
        request.tp = tp;
        request.deviation = 50;
        request.magic = m_magicNumber;
        request.comment = m_comment;
        request.type_filling = ORDER_FILLING_FOK;

        OrderSend(request, result);
    }

    int CountOpenPositions()
    {
        int count = 0;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == m_magicNumber)
                count++;
        }
        return count;
    }

    void CloseOppositePositions(bool isLongSignal)
    {
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;

            long posType = PositionGetInteger(POSITION_TYPE);
            bool isLongPosition = (posType == POSITION_TYPE_BUY);

            if((isLongSignal && !isLongPosition) || (!isLongSignal && isLongPosition))
            {
                MqlTradeRequest request = {};
                MqlTradeResult result = {};

                request.action = TRADE_ACTION_DEAL;
                request.position = ticket;
                request.symbol = _Symbol;
                request.volume = PositionGetDouble(POSITION_VOLUME);
                request.type = isLongPosition ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                request.price = isLongPosition ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                request.deviation = 50;
                request.magic = m_magicNumber;

                OrderSend(request, result);
            }
        }
    }
};

EMAIndicator* g_ema = NULL;
ATRIndicator* g_atr = NULL;
AsianSessionRange* g_asianRange = NULL;
BreakoutSignalGenerator* g_signalGenerator = NULL;
ATRRiskManager* g_riskManager = NULL;
TradingStrategy* g_strategy = NULL;

int OnInit()
{
    g_logger = new CBacktestLoggerAuto();
    if(g_logger != NULL)
        g_logger.SetEAInfo(TradeComment, "1.00", 1);
    else
        return INIT_FAILED;

    g_ema = new EMAIndicator(EMA_Period);
    g_atr = new ATRIndicator(ATR_Period);

    if(!g_ema.IsValid() || !g_atr.IsValid())
    {
        delete g_ema;
        delete g_atr;
        delete g_logger;
        return INIT_FAILED;
    }

    g_asianRange = new AsianSessionRange();
    g_signalGenerator = new BreakoutSignalGenerator(g_ema, g_asianRange, g_atr, OnlyLongs,
                                                     EnableATRFilter, MinATRPercent, MaxATRPercent, ATRLookbackPeriods,
                                                     EnableDistanceFilter, MaxDistanceFromEMA_ATR,
                                                     StrictMinATRPercent, StrictMaxDistanceFromEMA_ATR);
    g_riskManager = new ATRRiskManager(RiskPercent, SL_ATR_Multiplier, TP_ATR_Multiplier, BE_ATR_Multiplier, MagicNumber);

    g_strategy = new TradingStrategy(g_signalGenerator, g_riskManager, g_atr, MagicNumber, TradeComment, MaxTradesPerDay,
                                     DrawdownLookbackTrades, MaxDrawdownPercent, CooldownDays,
                                     EnableTrailingDD, MaxTrailingDDPercent, ReducedRiskPercent, TrailingDDRecoveryPercent, RiskPercent);

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    if(g_logger != NULL)
    {
        g_logger.ExportToJSON();
        delete g_logger;
    }

    delete g_strategy;
    delete g_riskManager;
    delete g_signalGenerator;
    delete g_asianRange;
    delete g_atr;
    delete g_ema;
}

void OnTick()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime == lastBarTime) return;
    lastBarTime = currentBarTime;

    if(g_logger != NULL)
        g_logger.UpdateBalancePeaks();

    if(g_strategy != NULL)
        g_strategy.Execute();
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
    if(g_logger != NULL)
        g_logger.ProcessDeal(trans);

    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(HistoryDealSelect(trans.deal))
        {
            long dealEntry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
            {
                if(g_strategy != NULL)
                    g_strategy.UpdateBalanceHistory();
            }
        }
    }
}