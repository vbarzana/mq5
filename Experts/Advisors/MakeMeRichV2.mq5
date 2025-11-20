//+------------------------------------------------------------------+
//|                                                   MakeMeRich.mq5 |
//|                                    Victor Antonio Barzana Crespo |
//|                                                                  |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <MyClasses\GetIndicatorBuffers.mqh>
CTrade trade;

#property   copyright         "Victor Antonio Barzana Crespo"
#property   link              ""
#property   version           "1.00"

#define     LONG_MAGIC        1234561   // MagicNumber of the expert
#define     SHORT_MAGIC       1234562   // MagicNumber of the expert

double      _volume           = 0.1;
int         stopLossLevel     = 150;
int         MAX_LOSS_IN_PIPS  = 250;
int         takeProfitLevel   = 3000;
int         FAST_EMA          = 12;
int         SLOW_EMA          = 26;
int         SERIES_DEFAULT    = 9;
bool        isShortOpen       = false;
bool        isLongOpen        =  false;
datetime    currentTime;
int         currentTick       = 0;
datetime    bartime           = 0; // store open time of the current bar 
double      CROSS_FACTOR      = 0.00008;
int         BUFFER_SIZE       = 3;
double      MacdMain[];
double      MacdSignal[];


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // do not run the algo for the same ticker again
   if(!isNewBar())
   {
      return;
   }
   
   takePartialProfitsIfNeeded();
   
   int iMACD_handle=iMACD(_Symbol, _Period, FAST_EMA, SLOW_EMA, SERIES_DEFAULT, PRICE_CLOSE);
    if(iMACD_handle < 0)
     {
      Print("The creation of iMACD has failed: Runtime error =",GetLastError());
      //--- forced program termination
      return;
     }
   
   if(!GetMACDBuffers(iMACD_handle, 0, BUFFER_SIZE, MacdMain, MacdSignal, true)) return;
   
   ArrayReverse(MacdSignal);
   ArrayReverse(MacdMain);
   
   double currMacd = MacdMain[0];
   double currSignal = MacdSignal[0];
   double nextMacd = MacdMain[1];
   double nextSignal = MacdSignal[1];
   
   //double RsiBuffer[];
   //int RSI = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   //CopyBuffer(RSI, 0, 0, BUFFER_SIZE, RsiBuffer);
   
   bool hasSignalCrossed = hasSignalCrossed(MacdMain, MacdSignal);
      
   if(hasSignalCrossed && currMacd < currSignal && nextMacd >= nextSignal) // go Long
     {
          goLong();
     } 
     else if(hasSignalCrossed && currMacd > currSignal && nextMacd <= nextSignal) // go short
     {
          goShort();
     }
  }
 
  void InsertIntoArrayAndRemoveLast(double &array[], double item)
  {
      double newArray[];
      ArrayCopy(newArray, array, 0, 0, ArraySize(array) -1);
      newArray[0] = item;
      ArrayCopy(array, newArray);
      ArrayPrint(array);
  }
 
  void goLong()
  {
      CloseAllPositions(0);
      if(getPositionsCount(0) == 0)
      {
         SendLongOrder(LONG_MAGIC);
      }
  }
  
   void goShort()
  {
      CloseAllPositions(LONG_MAGIC);
     if(getPositionsCount(0) == 0)
     {
         SendShortOrder(SHORT_MAGIC);
     }
  }
  
  // direction 0 for down and 1 for up
  bool hasSignalCrossed(double &s0[], double &s1[])
  {
      return (s0[0] > s1[0] && s0[1]<=s1[1]) || (s0[0] < s1[0] && s0[1]>=s1[1]);
  }
  /* bool crossedUpOrDownFromPos(double &s0[], double &s1[], int direction)
  {
      int total = ArraySize(s0);
      bool down = direction == 0;
      bool wasEqual = false;
      bool wasUnder = false;
      int pos = 0;
      bool crossed = false;
      while(pos < total && !(crossed = crosses(s0[pos], s1[pos])))
      {
         pos++;
      }
      if(!crossed) return false;
      for(pos = pos; pos<total; pos++)
      {
         if(( (down && s0[pos] > s1[pos]) || (!down && s0[pos] < s1[pos])))
         {
            return true;
         }
     }
    
     return false;
  }*/
  
   bool crosses(double a, double b){
      double factor = CROSS_FACTOR;
      double subtraction = (b > a)? b-a: a-b;
      return MathAbs(subtraction) <= factor;
   }
    
  int getPositionsCount(long const magic_number)
  {
   int total=0;
    
    for (int i=0; i < PositionsTotal() ; i++) {
      CPositionInfo m_position;
      if(m_position.SelectByIndex(i)) {
         if (m_position.Symbol()==_Symbol && (!magic_number || (m_position.Magic()==magic_number))) {
             total++;
         }
      }
    }
    return total;
  }
  
  //+------------------------------------------------------------------+ 
//|  Return 'true' when a new bar appears                            | 
//+------------------------------------------------------------------+ 
bool isNewBar(const bool print_log=true) 
  {
//--- get open time of the zero bar 
   datetime currbar_time=iTime(_Symbol,_Period,0); 
//--- if open time changes, a new bar has arrived 
   if(bartime!=currbar_time) 
     {
      bartime=currbar_time; 
      //--- display data on open time of a new bar in the log       
      if(print_log && !(MQLInfoInteger(MQL_OPTIMIZATION)||MQLInfoInteger(MQL_TESTER))) 
        { 
         //--- display a message with a new bar open time 
         PrintFormat("%s: new bar on %s %s opened at %s",__FUNCTION__,_Symbol, 
                     StringSubstr(EnumToString(_Period),7), 
                     TimeToString(TimeCurrent(),TIME_SECONDS)); 
         //--- get data on the last tick 
         MqlTick last_tick; 
         if(!SymbolInfoTick(Symbol(),last_tick)) 
            Print("SymbolInfoTick() failed, error = ",GetLastError()); 
         //--- display the last tick time up to milliseconds 
         PrintFormat("Last tick was at %s.%03d", 
                     TimeToString(last_tick.time,TIME_SECONDS),last_tick.time_msc%1000); 
        } 
      //--- we have a new bar 
      return (true); 
     } 
//--- no new bar 
   return (false); 
  }
 
  void takePartialProfitsIfNeeded() 
  {
       MqlTick last_tick;
      SymbolInfoTick(_Symbol, last_tick);
      //--- calculate price according to the type
      double priceBid = last_tick.bid; // depart from price Bid
      double priceAsk = last_tick.ask; // depart from price Bid
      double tp;
      double openPrice;
      double currentPrice;
      long type;
      int total = PositionsTotal();
      double leftVolume;
      for (int i=total-1; i >= 0; i--) {
         CPositionInfo m_position;
         if(
            !m_position.SelectByIndex(i) || 
            m_position.Symbol()!=_Symbol ||
            m_position.TakeProfit() == 0 || 
            m_position.PriceCurrent() == 0
          ) {
            continue;
         }
         ulong ticket = m_position.Ticket();
         // Proceed to check if position needs to be closed
         m_position.InfoDouble(POSITION_TP, tp);
         m_position.InfoDouble(POSITION_PRICE_OPEN, openPrice);
         m_position.InfoDouble(POSITION_PRICE_CURRENT, currentPrice);
         type = m_position.PositionType();
         leftVolume = m_position.Volume();
         
         double nextChunkSize = _volume / 2;
         bool isLastChunk = leftVolume == nextChunkSize;
         bool isLongWithSomeProfit = type == POSITION_TYPE_BUY && priceBid > openPrice;
         bool isShortWithSomeProfit = type == POSITION_TYPE_SELL && priceAsk < openPrice;
         double priceOpenLong = priceBid - openPrice;
         double priceOpenShort = openPrice - priceAsk;
         double priceLevel = (isLongWithSomeProfit ? priceOpenLong: priceOpenShort);
         double priceHalfPosition = (takeProfitLevel / 4) * _Point;
         
         bool isHalfPositionLevel = priceLevel >= priceHalfPosition;
         // if price is below half position already taken, take the rest, it will probably go down
         bool shouldGoBreakEven = priceLevel < priceHalfPosition - 300 * _Point || priceLevel <= 30 * _Point;
         bool shouldTakeSmallProfit = priceLevel >= (takeProfitLevel / 1.7) * _Point;

         bool shouldCloseHalfPosition = isHalfPositionLevel && leftVolume > _volume/2;
         bool shouldCloseRemainingPosition = (shouldTakeSmallProfit || shouldGoBreakEven) && leftVolume <= _volume/2;
         
         if(isLongWithSomeProfit || isShortWithSomeProfit)
         {
            // take volume chunks of half or third part
            if(shouldCloseHalfPosition)
            {
              trade.PositionClosePartial(ticket, nextChunkSize);
            } 
            else if(shouldCloseRemainingPosition)
            {
               trade.PositionClose(ticket);
            }
         }
       }
  }
  
  
  
//+------------------------------------------------------------------+
//| Deletes all pending orders with specified ORDER_MAGIC            |
//+------------------------------------------------------------------+
void CloseAllPositions(long const magic_number)
  {
   CPositionInfo m_position;
   int total = PositionsTotal();
   for (int i=total-1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         if (m_position.Symbol()==_Symbol && (!magic_number || m_position.Magic()==magic_number)) {
               trade.PositionClose(m_position.Ticket());  // Close the selected position 
         }
      }
    }
  }
  
  
   MqlRates getPreviousBar()
  {
   // Rates Structure for the data of the Last incomplete BAR
      MqlRates BarData[1];
      CopyRates(_Symbol, _Period, 1, 1, BarData);
   
   // Copy latest close prijs.
      return BarData[0];
  }
  
  
  double GetStopLossForPrice(double price, int shortOrLong)
  {
      MqlRates previousBar = getPreviousBar();
      double riskPrice;
      double maxRiskPrice;
      double slCurrentPrice;
      if(shortOrLong == 0) // if long
        {
            riskPrice = NormalizeDouble(previousBar.low - stopLossLevel *_Point, _Digits);
            slCurrentPrice = NormalizeDouble(price - stopLossLevel *_Point, _Digits);
            maxRiskPrice = NormalizeDouble(price - MAX_LOSS_IN_PIPS*_Point, _Digits);
            if(slCurrentPrice < riskPrice)
            {
               riskPrice = slCurrentPrice;
            }
        } else // for shorts
        {
            riskPrice = NormalizeDouble(previousBar.high + stopLossLevel *_Point, _Digits);
            slCurrentPrice = NormalizeDouble(price + stopLossLevel *_Point, _Digits);
            maxRiskPrice = NormalizeDouble(price + MAX_LOSS_IN_PIPS*_Point, _Digits);
            if(slCurrentPrice > riskPrice)
            {
               riskPrice = slCurrentPrice;
            }
        }
      return (riskPrice > maxRiskPrice ? maxRiskPrice : riskPrice);
  }
  
//+------------------------------------------------------------------+
//| Sets a pending order in a random way                             |
//+------------------------------------------------------------------+
bool SendLongOrder(long const magic_number)
  {
  double price = GetCurrentLongPrice();
  double sl = GetStopLossForPrice(price, 0);
  double tp = NormalizeDouble(price + takeProfitLevel * _Point, _Digits);
  
  return trade.Buy(_volume, _Symbol, 0.0, sl, tp);
  /*
//--- prepare a request
   MqlTradeRequest request={0};
   request.action=TRADE_ACTION_PENDING;         // setting a pending order
   request.magic=magic_number;                  // ORDER_MAGIC
   request.symbol=_Symbol;                      // symbol
   request.volume=_volume;                      // volume in 0.1 lots
//--- form the order type
   request.type=ORDER_TYPE_BUY;                 // order type
//--- form the price for the pending order
   request.price= GetCurrentLongPrice();  // open price
   request.sl = GetStopLossForPrice(request.price, 0);
   request.tp= NormalizeDouble(request.price + takeProfitLevel * _Point, _Digits);
//--- send a trade request
   MqlTradeResult result={0};
   bool successful = OrderSend(request,result);
//--- write the server reply to log  
   Print(__FUNCTION__,":"," successful=", successful, ", result=",result.comment);
   if(result.retcode==10016) Print(result.bid,result.ask,result.price);
//--- return code of the trade server reply
   
   return result.retcode;
   */
  }
  
  uint SendShortOrder(long const magic_number)
  {
     double price = GetCurrentShortPrice();
     double sl = GetStopLossForPrice(price, 1);
     double tp = NormalizeDouble(price - takeProfitLevel * _Point, _Digits);
     
     return trade.Sell(_volume, _Symbol, price, sl, tp);
  /*
//--- prepare a request
   MqlTradeRequest request={0};
   request.action=TRADE_ACTION_PENDING;         // setting a pending order
   request.magic=magic_number;                  // ORDER_MAGIC
   request.symbol=_Symbol;                      // symbol
   request.volume=_volume;                          // volume in 0.1 lots
//--- form the order type
   request.type=ORDER_TYPE_SELL_LIMIT;                // order type
//--- form the price for the pending order
   // risk off of the previous 
   request.price= GetCurrentShortPrice();
   request.sl = GetStopLossForPrice(request.price, 1);
   request.tp= NormalizeDouble(request.price - takeProfitLevel * _Point, _Digits);
//--- send a trade request
   MqlTradeResult result={0};
   bool successful = OrderSend(request,result);
//--- write the server reply to log  
   Print(__FUNCTION__,":"," successful=", successful, ", result=",result.comment);
   if(result.retcode==10016) Print(result.bid,result.ask,result.price);
//--- return code of the trade server reply
   return result.retcode;*/
  }
  
//+------------------------------------------------------------------+
//| Returns price in a random way                                    |
//+------------------------------------------------------------------+
double GetCurrentLongPrice()
  {
   int distance = (int) SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(distance == 0) distance = 1;
   //-- receive data of the last tick
   MqlTick last_tick;
   SymbolInfoTick(_Symbol, last_tick);
   //--- calculate price according to the type
   double price = last_tick.bid; // depart from price Bid
   return price + distance*_Point;
  }
  
  double GetCurrentShortPrice()
  {
   int distance = (int) SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(distance == 0) distance = 1;
   //-- receive data of the last tick
   MqlTick last_tick={0};
   SymbolInfoTick(_Symbol, last_tick);
   //--- calculate price according to the type
   double price = last_tick.ask; // depart from price Ask
   return price - distance * _Point;
  }