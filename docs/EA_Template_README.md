# 📘 Plantilla Base para EAs de MT5

## 🎯 Descripción

Esta es una plantilla modular y lista para usar que sirve como base para crear nuevos Expert Advisors (EAs) en MetaTrader 5. Está completamente preparada para:

- ✅ **Compilar sin errores**
- ✅ **Exportar datos de backtest a JSON**
- ✅ **Sistema de logging profesional integrado**
- ✅ **Gestión de riesgo básica**
- ✅ **Estructura modular y limpia**

## 📦 Archivos Incluidos

```
mt5/MQL5/
├── Experts/
│   └── EA_Template.mq5          # Plantilla principal
└── Include/
    └── BacktestLogger.mqh       # Sistema de logging JSON
```

## 🚀 Cómo Usar la Plantilla

### 1. Crear un Nuevo EA

1. **Duplica el archivo de plantilla:**
   ```
   EA_Template.mq5 → Mi_Nuevo_EA.mq5
   ```

2. **Actualiza la información del EA:**
   ```cpp
   #property copyright "Tu Nombre"
   #property version   "1.00"

   // En OnInit():
   g_logger.SetEAInfo("Mi_Nuevo_EA", "1.00", 1);
   ```

### 2. Agregar Indicadores

**Ejemplo: Agregar un EMA:**

```cpp
// Variables globales
int handleEMA;
double emaBuffer[];

// En OnInit():
handleEMA = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
if(handleEMA == INVALID_HANDLE)
{
    Print("ERROR: No se pudo crear el indicador EMA");
    return(INIT_FAILED);
}
ArraySetAsSeries(emaBuffer, true);

// En OnDeinit():
if(handleEMA != INVALID_HANDLE)
    IndicatorRelease(handleEMA);

// En OnTick():
if(CopyBuffer(handleEMA, 0, 0, 3, emaBuffer) <= 0)
    return;
```

### 3. Implementar Lógica de Trading

**Descomenta y modifica las funciones de ejemplo:**

```cpp
//+------------------------------------------------------------------+
//| En OnTick() - Después de copiar indicadores                      |
//+------------------------------------------------------------------+

// 1. Verificar si ya hay posición abierta
if(HasOpenPosition())
{
    // Gestionar posición existente
    return;
}

// 2. Analizar señales
int signal = GetTradeSignal();

// 3. Ejecutar trades
if(signal == 1)
    OpenBuyOrder();
else if(signal == -1)
    OpenSellOrder();
```

**Implementa tu lógica de señales:**

```cpp
int GetTradeSignal()
{
    double ema_current = emaBuffer[1];
    double ema_previous = emaBuffer[2];
    double price = iClose(_Symbol, PERIOD_CURRENT, 1);

    if(price > ema_current && price_previous <= ema_previous)
        return 1;  // COMPRA

    if(price < ema_current && price_previous >= ema_previous)
        return -1; // VENTA

    return 0; // Sin señal
}
```

### 4. Logging de Trades

**Para guardar información completa de trades, usa una estructura:**

```cpp
// Variable global
struct OpenTradeContext
{
    ulong ticket;
    datetime open_time;
    double open_price;
    double sl;
    double tp;
    double volume;
    string direction;
    // Tus indicadores personalizados
    double ema;
    double rsi;
};
OpenTradeContext g_openTrades[100];
int g_openTradeCount = 0;

// Al abrir un trade (en OpenBuyOrder/OpenSellOrder):
if(result.retcode == TRADE_RETCODE_DONE)
{
    g_openTrades[g_openTradeCount].ticket = result.order;
    g_openTrades[g_openTradeCount].open_time = TimeCurrent();
    g_openTrades[g_openTradeCount].open_price = ask;
    g_openTrades[g_openTradeCount].direction = "LONG";
    g_openTrades[g_openTradeCount].ema = emaBuffer[1];
    // ... guardar más datos
    g_openTradeCount++;
}

// En OnTradeTransaction (al cerrar):
for(int i = 0; i < g_openTradeCount; i++)
{
    if(g_openTrades[i].ticket == positionID)
    {
        // Construir JSON de indicadores
        string indicators = StringFormat("{\"ema\":%.5f,\"rsi\":%.2f}",
                                          g_openTrades[i].ema,
                                          g_openTrades[i].rsi);

        // Loguear trade completo
        g_logger.LogTrade(
            positionID,
            g_openTrades[i].direction,
            g_openTrades[i].open_time,
            closeTime,
            g_openTrades[i].open_price,
            closePrice,
            g_openTrades[i].sl,
            g_openTrades[i].tp,
            g_openTrades[i].volume,
            profit,
            "TP",  // o "SL" o "TRAILING"
            indicators
        );
        break;
    }
}
```

## 📊 Exportación de Datos

### Archivo JSON Generado

Al finalizar el backtest, se genera automáticamente un archivo JSON en:

```
C:\Users\[TU_USUARIO]\AppData\Roaming\MetaQuotes\Terminal\[TERMINAL_ID]\MQL5\Files\
```

**Nombre del archivo:**
```
backtest_YYYYMMDD_HHMMSS.json
```

### Estructura del JSON

```json
{
  "metadata": {
    "ea_name": "Mi_EA",
    "ea_version": "1.00",
    "symbol": "BTCUSD",
    "timeframe": "H4",
    "test_start": "2024-01-01T00:00:00",
    "test_end": "2024-12-31T23:59:59",
    "initial_balance": 10000.00
  },
  "results": {
    "balance": {
      "final": 15000.00,
      "peak": 16000.00
    },
    "profit": {
      "net": 5000.00,
      "net_percent": 50.00
    },
    "drawdown": {
      "max_percent": 12.50
    },
    "statistics": {
      "win_rate": 65.00,
      "profit_factor": 2.50
    }
  },
  "trades": [
    {
      "ticket": 12345,
      "direction": "LONG",
      "open_price": 45000.00,
      "close_price": 46000.00,
      "profit": 500.00,
      "indicators": {
        "ema": 44800.00
      }
    }
  ]
}
```

## ⚙️ Parámetros Configurables

```cpp
input int    MagicNumber = 100000;           // Número mágico único
input string TradeComment = "EA_Template";   // Comentario de trades
input double RiskPercent = 2.0;              // Riesgo por trade (%)
input double MaxDrawdownPercent = 25.0;      // DD máximo permitido (%)
```

## 🔧 Funciones Incluidas

### Gestión de Riesgo

- ✅ `CalculateLotSize()` - Calcula lote según % de riesgo
- ✅ `IsMaxDrawdownReached()` - Verifica límite de DD
- ✅ `HasOpenPosition()` - Verifica posiciones abiertas

### Logging

- ✅ `g_logger.LogTrade()` - Registra trade completo
- ✅ `g_logger.LogEvent()` - Registra eventos personalizados
- ✅ `g_logger.LogRejectedSignal()` - Registra señales rechazadas
- ✅ `g_logger.UpdateBalancePeaks()` - Actualiza picos de balance/equity
- ✅ `g_logger.ExportToJSON()` - Exporta datos a JSON

## 📝 Checklist para Nuevo EA

- [ ] Duplicar plantilla con nuevo nombre
- [ ] Actualizar copyright y versión
- [ ] Agregar parámetros de entrada necesarios
- [ ] Crear handles de indicadores en `OnInit()`
- [ ] Implementar `GetTradeSignal()`
- [ ] Implementar `OpenBuyOrder()` y `OpenSellOrder()`
- [ ] Configurar estructura de contexto de trades
- [ ] Actualizar logging en `OnTradeTransaction()`
- [ ] Compilar y probar
- [ ] Verificar exportación JSON

## 🐛 Debugging

**Ver logs en MT5:**
1. Abrir "Toolbox" (Ctrl+T)
2. Pestaña "Experts"
3. Ver mensajes del EA

**Verificar archivo JSON:**
```cpp
// El logger imprime la ruta completa al exportar
Print("File: ", fullPath);
```

## 📚 Recursos

- **Documentación MQL5:** https://www.mql5.com/en/docs
- **BacktestLogger:** Ver `Include/BacktestLogger.mqh`
- **EA de ejemplo completo:** Ver `a4n_gold_ea_with_logging.mq5`

## 💡 Consejos

1. **Siempre guarda contexto de trades abiertos** para logging completo
2. **Normaliza todos los precios y valores** según digits del símbolo
3. **Verifica handles de indicadores** antes de copiar datos
4. **Usa `ArraySetAsSeries()`** para buffers de indicadores
5. **Prueba con visualization mode** activado en Strategy Tester

## 🎓 Ejemplo Completo

Para ver un ejemplo completo y funcional con:
- Múltiples indicadores (EMA200, EMA50, ATR)
- Detección de tendencia fuerte
- Trailing stop
- Filtros horarios
- Logging completo

Revisa: `a4n_gold_ea_with_logging.mq5`

---

**¡Listo para crear tu próximo EA ganador!** 🚀