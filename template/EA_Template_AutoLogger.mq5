//+------------------------------------------------------------------+
//|                                      EA_Template_AutoLogger.mq5  |
//|                        Template compatible con BacktestLoggerAuto |
//|                                                                   |
//|  Este template usa la librería 100% AUTÓNOMA BacktestLoggerAuto  |
//|                                                                   |
//|  VENTAJAS:                                                        |
//|  ✅ Código mínimo - solo 3 llamadas a la librería                |
//|  ✅ Logging automático de TODOS los trades                       |
//|  ✅ Funciona con múltiples magic numbers                         |
//|  ✅ Soporta múltiples posiciones simultáneas                     |
//|                                                                   |
//|  LIMITACIONES:                                                    |
//|  ❌ NO registra indicadores personalizados                       |
//|  ❌ Close reason puede ser impreciso si modificas TP/SL          |
//+------------------------------------------------------------------+
#property copyright "Trading Bot Lab"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                          |
//+------------------------------------------------------------------+
#include <BacktestLoggerAuto.mqh>

//+------------------------------------------------------------------+
//| PARÁMETROS DE ENTRADA                                            |
//+------------------------------------------------------------------+
input group "=== General Settings ==="
input int         MagicNumber = 100000;
input string      TradeComment = "EA_TEMPLATE";

input group "=== Risk Management ==="
input double      RiskPercent = 2.0;
input double      SL_Points = 50;
input double      TP_Points = 100;

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                                |
//+------------------------------------------------------------------+

// 🔹 PASO 1: Declarar el logger
CBacktestLoggerAuto* g_logger = NULL;

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("================================================");
    Print("🚀 STARTING: ", TradeComment);
    Print("================================================");

    // 🔹 PASO 2: Inicializar el logger
    g_logger = new CBacktestLoggerAuto();
    if(g_logger != NULL)
    {
        g_logger.SetEAInfo(TradeComment, "1.00", 1);

        // OPCIONAL: Especificar magic numbers a trackear (si omites esto, trackea TODOS)
        // long magics[] = {MagicNumber};
        // g_logger.SetMagicNumbers(magics);

        Print("✅ Logger initialized (AUTO mode)");
    }
    else
    {
        Print("❌ ERROR: Logger not initialized");
        return INIT_FAILED;
    }

    Print("================================================");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("================================================");
    Print("🛑 Stopping EA...");

    // 🔹 PASO 3a: Exportar datos al finalizar
    if(g_logger != NULL)
    {
        Print("📊 Exporting data...");
        g_logger.ExportToJSON();
        delete g_logger;
    }

    Print("✅ EA stopped correctly");
    Print("================================================");
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    // Solo operar en cierre de vela
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(currentBarTime == lastBarTime) return;
    lastBarTime = currentBarTime;

    // 🔹 PASO 3b: Actualizar peaks (para drawdown correcto)
    if(g_logger != NULL)
        g_logger.UpdateBalancePeaks();

    // ==========================================
    // TU LÓGICA DE TRADING AQUÍ
    // ==========================================

    // Ejemplo simple: Comprar si no hay posiciones
    if(CountOpenPositions() == 0)
    {
        // Tu señal de entrada aquí
        bool buySignal = true;  // Reemplaza con tu lógica

        if(buySignal)
        {
            OpenBuyOrder();
        }
    }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction                                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
    // 🔹 PASO 4: Procesar deals automáticamente
    // ⚠️ IMPORTANTE: Esta es la ÚNICA línea necesaria
    if(g_logger != NULL)
        g_logger.ProcessDeal(trans);
}

//+------------------------------------------------------------------+
//| FUNCIONES DE TRADING (EJEMPLO)                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Abrir orden de compra                                            |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    double sl = NormalizeDouble(ask - (SL_Points * point), digits);
    double tp = NormalizeDouble(ask + (TP_Points * point), digits);

    double slDistance = ask - sl;
    double lots = CalculateLotSize(slDistance);

    if(lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
    {
        Print("❌ Lot size too small");
        return;
    }

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

    if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
    {
        Print("✅ BUY order opened | Ticket: ", result.order);
        Print("   Entry: ", NormalizeDouble(ask, digits));
        Print("   SL: ", NormalizeDouble(sl, digits));
        Print("   TP: ", NormalizeDouble(tp, digits));
        Print("   Lot: ", lots);

        // ⚠️ NO NECESITAS GUARDAR NADA - El logger lo hace automáticamente
    }
    else
    {
        Print("❌ Error opening BUY: ", result.retcode, " - ", result.comment);
    }
}

//+------------------------------------------------------------------+
//| Calcular tamaño de lote                                          |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (RiskPercent / 100.0);

    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

    double moneyPerPoint = (tickSize != 0) ? (tickValue / tickSize) : 0;
    double lots = (moneyPerPoint != 0 && stopLossDistance != 0) ?
                  (riskAmount / (stopLossDistance * moneyPerPoint)) : 0;

    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if(lots < minLot) lots = minLot;
    if(lots > maxLot) lots = maxLot;

    lots = MathFloor(lots / lotStep) * lotStep;
    return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Contar posiciones abiertas                                       |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol &&
           PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+