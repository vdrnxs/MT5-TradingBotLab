//+------------------------------------------------------------------+
//|                                                    EA_Template.mq5|
//|                                          Plantilla Base para EAs  |
//|   Plantilla modular lista para exportación JSON de backtests     |
//+------------------------------------------------------------------+
#property copyright "Trading Bot Lab"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                          |
//+------------------------------------------------------------------+
#include <BacktestLogger.mqh>

//+------------------------------------------------------------------+
//| PARÁMETROS DE ENTRADA                                            |
//+------------------------------------------------------------------+
input group "=== Configuración General ==="
input int         MagicNumber = 100000;         // Número mágico
input string      TradeComment = "EA_Template";  // Comentario de operaciones

input group "=== Gestión de Riesgo ==="
input double      RiskPercent = 2.0;             // Riesgo por operación (%)
input double      MaxDrawdownPercent = 25.0;     // Drawdown máximo permitido (%)

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                                |
//+------------------------------------------------------------------+
double initialBalance = 0;                       // Balance inicial para calcular DD

// === SISTEMA DE LOGGING ===
CBacktestLogger* g_logger = NULL;

// === INDICADORES (Ejemplo - Agregar según necesidad) ===
// int handleIndicator;
// double indicatorBuffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("============================================");
    Print("Iniciando EA: ", TradeComment);
    Print("Símbolo: ", _Symbol);
    Print("Timeframe: ", EnumToString((ENUM_TIMEFRAMES)Period()));
    Print("============================================");

    //--- Guardar balance inicial
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    Print("Balance inicial: $", initialBalance);

    //--- Inicializar indicadores aquí (si los necesitas)
    // handleIndicator = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
    // if(handleIndicator == INVALID_HANDLE)
    // {
    //     Print("ERROR: No se pudo crear el indicador");
    //     return(INIT_FAILED);
    // }
    // ArraySetAsSeries(indicatorBuffer, true);

    //--- Inicializar logger
    g_logger = new CBacktestLogger();
    if(g_logger != NULL)
    {
        g_logger.SetEAInfo(TradeComment, "1.00", 1);
        Print("Logger inicializado correctamente");
    }
    else
    {
        Print("ERROR: No se pudo inicializar el logger");
        return(INIT_FAILED);
    }

    Print("============================================");
    Print("EA inicializado exitosamente");
    Print("Magic Number: ", MagicNumber);
    Print("Risk per trade: ", RiskPercent, "%");
    Print("Max Drawdown: ", MaxDrawdownPercent, "%");
    Print("============================================");

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("============================================");
    Print("Deteniendo EA...");
    Print("Razón: ", GetDeinitReasonText(reason));

    //--- Liberar handles de indicadores
    // if(handleIndicator != INVALID_HANDLE)
    //     IndicatorRelease(handleIndicator);

    //--- Exportar datos del backtest a JSON
    if(g_logger != NULL)
    {
        Print("Exportando datos a JSON...");
        g_logger.ExportToJSON();
        delete g_logger;
        g_logger = NULL;
    }

    Print("EA detenido correctamente");
    Print("============================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Verificar si es una nueva barra (operar solo en cierre de vela)
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);

    if(currentBarTime == lastBarTime)
        return;

    lastBarTime = currentBarTime;

    //--- Actualizar picos de balance/equity para drawdown
    if(g_logger != NULL)
        g_logger.UpdateBalancePeaks();

    //--- Copiar datos de indicadores
    // if(CopyBuffer(handleIndicator, 0, 0, 3, indicatorBuffer) <= 0)
    //     return;

    //--- Verificar drawdown máximo
    if(IsMaxDrawdownReached())
    {
        static bool ddWarningShown = false;
        if(!ddWarningShown)
        {
            Print("ADVERTENCIA: Drawdown máximo alcanzado. Trading detenido.");
            ddWarningShown = true;
        }
        return;
    }

    //--- AQUÍ VA LA LÓGICA DE TRADING
    // Ejemplo de estructura:

    // 1. Verificar si ya hay posición abierta
    // if(HasOpenPosition())
    // {
    //     // Gestionar posición existente (trailing stop, etc.)
    //     return;
    // }

    // 2. Analizar señales de trading
    // int signal = GetTradeSignal();
    //
    // 3. Ejecutar trades según señal
    // if(signal == 1)        // Señal de COMPRA
    // {
    //     OpenBuyOrder();
    // }
    // else if(signal == -1)  // Señal de VENTA
    // {
    //     OpenSellOrder();
    // }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction - Detectar cierre de trades                   |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
    if(g_logger == NULL) return;

    // Detectar cierre de posiciones (DEAL_ENTRY_OUT)
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        ulong dealTicket = trans.deal;
        if(HistoryDealSelect(dealTicket))
        {
            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

            if(entry == DEAL_ENTRY_OUT)
            {
                // Obtener información del deal cerrado
                ulong positionID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
                double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);

                // AQUÍ DEBERÍAS GUARDAR INFORMACIÓN AL ABRIR EL TRADE
                // Y RECUPERARLA AQUÍ PARA LOGUEARLO COMPLETAMENTE

                // Ejemplo de logueo de trade cerrado:
                // g_logger.LogTrade(
                //     positionID,              // ticket
                //     "LONG",                  // direction
                //     openTime,                // open_time
                //     closeTime,               // close_time
                //     openPrice,               // open_price
                //     closePrice,              // close_price
                //     sl,                      // sl
                //     tp,                      // tp
                //     volume,                  // volume
                //     profit,                  // profit
                //     "TP",                    // close_reason
                //     "{\"indicator\":0.0}"    // indicators_json
                // );

                Print("Trade cerrado | Ticket: ", positionID, " | Profit: $", profit);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| FUNCIONES AUXILIARES                                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Verificar si se alcanzó el drawdown máximo                       |
//+------------------------------------------------------------------+
bool IsMaxDrawdownReached()
{
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

    if(initialBalance == 0)
    {
        initialBalance = currentBalance;
        return false;
    }

    double drawdown = 0;
    if(initialBalance > 0)
    {
        drawdown = ((initialBalance - currentEquity) / initialBalance) * 100.0;
    }

    // Log periódico de estado (cada hora)
    static datetime lastPrintTime = 0;
    if(TimeCurrent() - lastPrintTime > 3600)
    {
        Print("Balance: $", currentBalance,
              " | Equity: $", currentEquity,
              " | DD: ", NormalizeDouble(drawdown, 2), "%");
        lastPrintTime = TimeCurrent();
    }

    return (drawdown >= MaxDrawdownPercent);
}

//+------------------------------------------------------------------+
//| Verificar si hay posición abierta                                |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Calcular tamaño de lote basado en riesgo                         |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (RiskPercent / 100.0);

    //--- Obtener valor del tick
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

    //--- Calcular el valor monetario por punto de SL
    double moneyPerPoint = 0;
    if(tickSize != 0)
        moneyPerPoint = tickValue / tickSize;

    //--- Calcular lote basado en el riesgo
    double lots = 0;
    if(moneyPerPoint != 0 && stopLossDistance != 0)
        lots = riskAmount / (stopLossDistance * moneyPerPoint);

    //--- Normalizar lote según los límites del símbolo
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if(lots < minLot) lots = minLot;
    if(lots > maxLot) lots = maxLot;

    lots = MathFloor(lots / lotStep) * lotStep;
    lots = NormalizeDouble(lots, 2);

    return lots;
}

//+------------------------------------------------------------------+
//| Obtener texto descriptivo del motivo de deinit                   |
//+------------------------------------------------------------------+
string GetDeinitReasonText(int reason)
{
    switch(reason)
    {
        case REASON_PROGRAM:     return "EA stopped by user";
        case REASON_REMOVE:      return "EA removed from chart";
        case REASON_RECOMPILE:   return "EA recompiled";
        case REASON_CHARTCHANGE: return "Chart symbol/period changed";
        case REASON_CHARTCLOSE:  return "Chart closed";
        case REASON_PARAMETERS:  return "Input parameters changed";
        case REASON_ACCOUNT:     return "Account changed";
        case REASON_TEMPLATE:    return "Template applied";
        case REASON_INITFAILED:  return "OnInit() returned INIT_FAILED";
        case REASON_CLOSE:       return "Terminal closed";
        default:                 return "Unknown reason";
    }
}

//+------------------------------------------------------------------+
//| FUNCIONES DE TRADING (Ejemplos comentados)                       |
//+------------------------------------------------------------------+

/*
//+------------------------------------------------------------------+
//| Detectar señal de trading                                        |
//| Retorna: 1=COMPRA, -1=VENTA, 0=SIN SEÑAL                         |
//+------------------------------------------------------------------+
int GetTradeSignal()
{
    // IMPLEMENTAR LÓGICA DE SEÑALES AQUÍ

    // Ejemplo:
    // double indicator1 = indicatorBuffer[1];
    // double indicator2 = indicatorBuffer[2];
    //
    // if(indicator1 > indicator2)
    //     return 1;  // COMPRA
    // else if(indicator1 < indicator2)
    //     return -1; // VENTA

    return 0; // Sin señal
}

//+------------------------------------------------------------------+
//| Abrir orden de compra                                            |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    //--- Calcular SL y TP
    double slDistance = 100 * _Point;  // Ejemplo: 100 pips
    double tpDistance = 200 * _Point;  // Ejemplo: 200 pips

    double sl = NormalizeDouble(ask - slDistance, digits);
    double tp = NormalizeDouble(ask + tpDistance, digits);

    //--- Calcular lote
    double lots = CalculateLotSize(slDistance);

    if(lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
    {
        Print("ERROR: Lote calculado muy pequeño: ", lots);
        return;
    }

    //--- Preparar request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lots;
    request.type = ORDER_TYPE_BUY;
    request.price = ask;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 50;
    request.magic = MagicNumber;
    request.comment = TradeComment;
    request.type_filling = ORDER_FILLING_FOK;

    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            Print("COMPRA EXITOSA | Ticket: ", result.order, " | Precio: ", ask);

            // Log del trade abierto
            if(g_logger != NULL)
            {
                string indicators = "{\"example\":0.0}";
                string data = StringFormat("{\"ticket\":%d,\"volume\":%.2f,\"sl\":%.5f,\"tp\":%.5f}",
                                            result.order, lots, sl, tp);
                g_logger.LogEvent("TRADE_OPEN", "Long trade opened", data);
            }
        }
        else
        {
            Print("ERROR al abrir COMPRA: ", result.retcode, " - ", result.comment);
        }
    }
}

//+------------------------------------------------------------------+
//| Abrir orden de venta                                             |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    //--- Calcular SL y TP
    double slDistance = 100 * _Point;  // Ejemplo: 100 pips
    double tpDistance = 200 * _Point;  // Ejemplo: 200 pips

    double sl = NormalizeDouble(bid + slDistance, digits);
    double tp = NormalizeDouble(bid - tpDistance, digits);

    //--- Calcular lote
    double lots = CalculateLotSize(slDistance);

    if(lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
    {
        Print("ERROR: Lote calculado muy pequeño: ", lots);
        return;
    }

    //--- Preparar request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lots;
    request.type = ORDER_TYPE_SELL;
    request.price = bid;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 50;
    request.magic = MagicNumber;
    request.comment = TradeComment;
    request.type_filling = ORDER_FILLING_FOK;

    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            Print("VENTA EXITOSA | Ticket: ", result.order, " | Precio: ", bid);

            // Log del trade abierto
            if(g_logger != NULL)
            {
                string indicators = "{\"example\":0.0}";
                string data = StringFormat("{\"ticket\":%d,\"volume\":%.2f,\"sl\":%.5f,\"tp\":%.5f}",
                                            result.order, lots, sl, tp);
                g_logger.LogEvent("TRADE_OPEN", "Short trade opened", data);
            }
        }
        else
        {
            Print("ERROR al abrir VENTA: ", result.retcode, " - ", result.comment);
        }
    }
}
*/

//+------------------------------------------------------------------+