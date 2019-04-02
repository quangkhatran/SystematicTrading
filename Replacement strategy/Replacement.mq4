/* 
RETRACEMENT STRATEGY
   
ENTRY RULES:
- Long when: 
   1. Closing price touch bottom line of Donchian(24).
   2. SMA(24) is greater than SMA(72). This indicates that we are in a up trend.
      
- Short when: 
   1. Closing price touch top line of Donchian(24).
   2. SMA(24) is less than SMA(72). This indicates that we are in a down trend.
      
EXIT RULES:
- Profit-Taking Exit 1: Exit the long trade when closing price moved up > 0.5 * Donchian(24) width. (defined as Donchian(24) top line - bottom line) 
- Profit-Taking Exit 2: Exit the short trade when closing price moved down > 0.5 * Donchian(24) width.
- Stop Loss Exits: Exit when closing price move 2 * ATR(24) in the averse direction.
      
- Stop Loss Exit: 2 ATR(24)
   
POSITION SIZING RULE:
- 2% of Capital risked per trade
      
*/

#define SIGNAL_NONE 0
#define SIGNAL_BUY   1
#define SIGNAL_SELL  2
#define SIGNAL_CLOSEBUY 3
#define SIGNAL_CLOSESELL 4

#property copyright "QuangKhaTran"
#property link      "quangkhatran@gmail.com"

extern int MagicNumber = 00003;
extern bool SignalMail = False;
extern double Lots = 1.0;
extern int Slippage = 3;
extern bool UseStopLoss = True;
extern int StopLoss = 0;
extern bool UseTakeProfit = True;
extern int TakeProfit = 0;
extern bool UseTrailingStop = False;
extern int TrailingStop = 0;
extern bool isSizingOn = True;
extern int Risk = 2;

// Declare Extern Variables

extern string Donchian_variables;
extern int Periods_Entry=24;
extern int Extremes=3;
extern int Margins=-2;
extern int Advance=0;
extern int max_bars=1000;
extern string Donchian_variables_end;
extern double tpDC_k = 0.5; // Take Profit Multiple of donchian
extern double slATR_k = 2; // Stop Loss Multiple of ATR
extern int atr_period = 24; // Used for stop loss
extern int smaPeriodShort = 24;
extern int smaPeriodLong = 72;

int P = 1;
int Order = SIGNAL_NONE;
int Total, Ticket, Ticket2;
double StopLossLevel, TakeProfitLevel, StopLevel;
bool isYenPair;

// Declare variables
double donchianTop1, donchianTop2, donchianBottom1, donchianBottom2, donchianWidth, close1, close2;
double atr_current, atr_past;
double takeprofit1, takeprofit2;
double timeexit;
double sma_short, sma_long;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   
   if(Digits == 5 || Digits == 3 || Digits == 1)P = 10;else P = 1; // To account for 5 digit brokers
   if(Digits == 3 || Digits == 2) isYenPair = True; // To account for Yen Pairs


   return(0);
}
//+------------------------------------------------------------------+
//| Expert initialization function - END                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() {
   return(0);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function - END                           |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert start function                                            |
//+------------------------------------------------------------------+
int start() {

   Total = OrdersTotal();
   Order = SIGNAL_NONE;

   //+------------------------------------------------------------------+
   //| Variable Setup                                                   |
   //+------------------------------------------------------------------+

   // Initialise Donchian indicators
   
   donchianTop1 = iCustom(NULL, 0, "Donchian Channels", Periods_Entry, Extremes, Margins, Advance, max_bars, 1, 1);
   donchianTop2 = iCustom(NULL, 0, "Donchian Channels", Periods_Entry, Extremes, Margins, Advance, max_bars, 1, 2);
   donchianBottom1 = iCustom(NULL, 0, "Donchian Channels", Periods_Entry, Extremes, Margins, Advance, max_bars, 0, 1);
   donchianBottom2 = iCustom(NULL, 0, "Donchian Channels", Periods_Entry, Extremes, Margins, Advance, max_bars, 0, 2);

   // Initialise MAs
   
   sma_short = iMA(NULL, 0, smaPeriodShort, 0, 0, 0, 1);
   sma_long = iMA(NULL, 0, smaPeriodLong, 0, 0, 0, 1);

   // Calculate donchianWidth and ATR(20)
   
   donchianWidth = donchianTop1 - donchianBottom1;
   atr_current = iATR(NULL, 0, atr_period, 1);    // ATR(20)

   // Initialise Closing Price Variables
   
   close1 = iClose(NULL, 0, 1);
   close2 = iClose(NULL, 0, 2);
   
   // Declare Stop Loss and Take Profits Exits
   
   StopLoss = slATR_k * atr_current / (P * Point); // Note that StopLoss need to be initialised before the Sizing Algo as we are using this value there
   TakeProfit = tpDC_k * donchianWidth / (P * Point);  // Take Profit 2 Donchian(24);
   
   // Sizing Algo (2% risked per trade)
   if (isSizingOn == true) {
      Lots = Risk * 0.01 * AccountBalance() / (MarketInfo(Symbol(),MODE_LOTSIZE) * StopLoss * P * Point); // Sizing Algo based on account size
      if(isYenPair == true) Lots = Lots * 100; // Adjust for Yen Pairs
      Lots = NormalizeDouble(Lots, 2); // Round to 2 decimal place
   }

   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD)) / P; // Defining minimum StopLevel

   if (StopLoss < StopLevel) StopLoss = StopLevel;
   if (TakeProfit < StopLevel) TakeProfit = StopLevel;

   //+------------------------------------------------------------------+
   //| Variable Setup - END                                             |
   //+------------------------------------------------------------------+

   //Check position
   bool IsTrade = False;

   for (int i = 0; i < Total; i ++) {
      Ticket2 = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if(OrderType() <= OP_SELL &&  OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
         IsTrade = True;
         if(OrderType() == OP_BUY) {
            //Close

            //+------------------------------------------------------------------+
            //| Signal Begin(Exit Buy)                                           |
            //+------------------------------------------------------------------+

            /* 
            EXIT RULES:
            - Profit-Taking Exit 1: Exit the long trade when closing price moved up > 1 Donchian(24) width. (defined as Donchian(24) top line - bottom line) 
            - Profit-Taking Exit 2: Exit the short trade when closing price moved down > 1 Donchian(24) width.
            */
            
            // Exit rules are incorporated into the StopLoss and TakeProfit Variables
            
            //if() Order = SIGNAL_CLOSEBUY; // Rule to EXIT a Long trade

            //+------------------------------------------------------------------+
            //| Signal End(Exit Buy)                                             |
            //+------------------------------------------------------------------+

            if (Order == SIGNAL_CLOSEBUY) {
               Ticket2 = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, MediumSeaGreen);
               if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + " Close Buy");
               IsTrade = False;
               continue;
            }
            //Trailing stop
            if(UseTrailingStop && TrailingStop > 0) {                 
               if(Bid - OrderOpenPrice() > P * Point * TrailingStop) {
                  if(OrderStopLoss() < Bid - P * Point * TrailingStop) {
                     Ticket2 = OrderModify(OrderTicket(), OrderOpenPrice(), Bid - P * Point * TrailingStop, OrderTakeProfit(), 0, MediumSeaGreen);
                     continue;
                  }
               }
            }
         } else {
            

            //+------------------------------------------------------------------+
            //| Signal Begin(Exit Sell)                                          |
            //+------------------------------------------------------------------+

            //if () Order = SIGNAL_CLOSESELL; // Rule to EXIT a Short trade

            //+------------------------------------------------------------------+
            //| Signal End(Exit Sell)                                            |
            //+------------------------------------------------------------------+

            if (Order == SIGNAL_CLOSESELL) {
               Ticket2 = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, DarkOrange);
               if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + " Close Sell");               
               IsTrade = False;
               continue;
            }
            //Trailing stop
            if(UseTrailingStop && TrailingStop > 0) {                 
               if((OrderOpenPrice() - Ask) > (P * Point * TrailingStop)) {
                  if((OrderStopLoss() > (Ask + P * Point * TrailingStop)) || (OrderStopLoss() == 0)) {
                     Ticket2 = OrderModify(OrderTicket(), OrderOpenPrice(), Ask + P * Point * TrailingStop, OrderTakeProfit(), 0, DarkOrange);
                     continue;
                  }
               }
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Signal Begin(Entries)                                            |
   //+------------------------------------------------------------------+

      /*
      ENTRY RULES:
      - Long when: Closing price touch bottom line of Donchian(24)
      - Short when: Closing price touch top line of Donchian(24)
      */
   
   // Add all entry rules
   
      if (sma_short > sma_long) if (close2 > donchianBottom2 && close1 <= donchianBottom1 ) Order = SIGNAL_BUY; // Rule to ENTER a Long trade
   
      if (sma_short < sma_long) if (close2 < donchianTop2 && close1 >= donchianTop1) Order = SIGNAL_SELL; // Rule to ENTER a Short trade

   //+------------------------------------------------------------------+
   //| Signal End                                                       |
   //+------------------------------------------------------------------+

   //Buy
   if (Order == SIGNAL_BUY) {
      if(!IsTrade) {
         //Check free margin
         if (AccountFreeMargin() < (1000 * Lots)) {
            Print("We have no money. Free Margin = ", AccountFreeMargin());
            return(0);
         } 

         if (UseStopLoss) StopLossLevel = Ask - StopLoss * Point * P; else StopLossLevel = 0.0;
         if (UseTakeProfit) TakeProfitLevel = Ask + TakeProfit * Point * P; else TakeProfitLevel = 0.0;

         Ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, StopLossLevel, TakeProfitLevel, "Buy(#" + MagicNumber + ")", MagicNumber, 0, DodgerBlue);
         if(Ticket > 0) {
            if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
				Print("BUY order opened : ", OrderOpenPrice());
                if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Ask, Digits) + " Open Buy");
			   
			} else {
				Print("Error opening BUY order : ", GetLastError());
			}
         }
         return(0);
      }
   }

   //Sell
   if (Order == SIGNAL_SELL) {
      if(!IsTrade) {
         //Check free margin
         if (AccountFreeMargin() < (1000 * Lots)) {
            Print("We have no money. Free Margin = ", AccountFreeMargin());
            return(0);
         }

         if (UseStopLoss) StopLossLevel = Bid + StopLoss * Point * P; else StopLossLevel = 0.0;
         if (UseTakeProfit) TakeProfitLevel = Bid - TakeProfit * Point * P; else TakeProfitLevel = 0.0;

         Ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, StopLossLevel, TakeProfitLevel, "Sell(#" + MagicNumber + ")", MagicNumber, 0, DeepPink);
         if(Ticket > 0) {
            if (OrderSelect(Ticket, SELECT_BY_TICKET, MODE_TRADES)) {
				Print("SELL order opened : ", OrderOpenPrice());
                if (SignalMail) SendMail("[Signal Alert]", "[" + Symbol() + "] " + DoubleToStr(Bid, Digits) + " Open Sell");
	
			} else {
				Print("Error opening SELL order : ", GetLastError());
			}
         }
         return(0);
      }
   }


   return(0);
}
//+------------------------------------------------------------------+

