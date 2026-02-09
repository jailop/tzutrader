mod indicators;

use indicators::{
    Indicator, Ohlcv,
    base::BaseIndicator,
    ma::MA,
    ema::EMA,
    rsi::RSI,
    macd::{MACD, MACDValues},
    bollinger::{BollingerBands, BollingerValues},
    atr::ATR,
    roc::ROC,
    mom::MOM,
};

fn main() {
    println!("=== TzuTrader-RS: Technical Indicators Demo ===\n");
    
    // Example 1: Simple Moving Average
    println!("1. Simple Moving Average (SMA):");
    let mut ma = MA::<5, 3>::new();
    for i in 1..=10 {
        ma.update(i as f64);
    }
    println!("   Current: {:.2}", ma.get(0));
    println!("   Previous: {:.2}", ma.get(-1));
    println!("   Two bars ago: {:.2}\n", ma.get(-2));
    
    // Example 2: Exponential Moving Average
    println!("2. Exponential Moving Average (EMA):");
    let mut ema = EMA::<5, 1>::new();
    for i in 1..=10 {
        ema.update(i as f64);
    }
    println!("   Current EMA: {:.2}\n", ema.get(0));
    
    // Example 3: RSI with OHLCV data
    println!("3. Relative Strength Index (RSI):");
    let mut rsi = RSI::<14, 1>::new();
    let bars = vec![
        Ohlcv { open: 100.0, high: 102.0, low: 99.0, close: 101.0, volume: 1000.0 },
        Ohlcv { open: 101.0, high: 103.0, low: 100.0, close: 102.5, volume: 1100.0 },
        Ohlcv { open: 102.5, high: 104.0, low: 101.5, close: 103.0, volume: 1200.0 },
    ];
    
    for bar in bars.iter().take(3) {
        rsi.update(*bar);
    }
    
    // Add more bars to get a valid RSI
    for i in 4..=20 {
        let bar = Ohlcv {
            open: 100.0 + i as f64,
            high: 102.0 + i as f64,
            low: 99.0 + i as f64,
            close: 101.0 + i as f64,
            volume: 1000.0,
        };
        rsi.update(bar);
    }
    
    let rsi_val = rsi.get(0);
    if !rsi_val.is_nan() {
        println!("   RSI: {:.2}\n", rsi_val);
    } else {
        println!("   RSI: Not enough data\n");
    }
    
    // Example 4: MACD
    println!("4. Moving Average Convergence Divergence (MACD):");
    let mut macd = MACD::<12, 26, 9, 3>::new();
    for i in 1..=50 {
        macd.update(100.0 + (i as f64 * 0.5));
    }
    let macd_vals = macd.get_values(0);
    println!("   MACD: {:.4}", macd_vals.macd);
    println!("   Signal: {:.4}", macd_vals.signal);
    println!("   Histogram: {:.4}\n", macd_vals.hist);
    
    // Example 5: Bollinger Bands
    println!("5. Bollinger Bands:");
    let mut bb = BollingerBands::<20, 1>::new();
    for i in 1..=30 {
        bb.update(100.0 + (i as f64 % 10.0));
    }
    let bb_vals = bb.get_values(0);
    println!("   Upper Band: {:.2}", bb_vals.upper);
    println!("   Middle Band: {:.2}", bb_vals.middle);
    println!("   Lower Band: {:.2}\n", bb_vals.lower);
    
    // Example 6: Average True Range (ATR)
    println!("6. Average True Range (ATR):");
    let mut atr = ATR::<14, 1>::new();
    for i in 1..=20 {
        let bar = Ohlcv {
            open: 100.0,
            high: 102.0 + (i as f64 % 5.0),
            low: 98.0 - (i as f64 % 3.0),
            close: 101.0,
            volume: 1000.0,
        };
        atr.update(bar);
    }
    println!("   ATR: {:.2}\n", atr.get(0));
    
    // Example 7: Rate of Change
    println!("7. Rate of Change (ROC):");
    let mut roc = ROC::<10, 1>::new();
    for i in 1..=15 {
        roc.update(100.0 + (i as f64 * 2.0));
    }
    let roc_val = roc.get(0);
    if !roc_val.is_nan() {
        println!("   ROC: {:.2}%\n", roc_val);
    }
    
    // Example 8: Momentum
    println!("8. Momentum (MOM):");
    let mut mom = MOM::<10, 1>::new();
    for i in 1..=15 {
        mom.update(100.0 + (i as f64 * 1.5));
    }
    let mom_val = mom.get(0);
    if !mom_val.is_nan() {
        println!("   Momentum: {:.2}\n", mom_val);
    }
    
    // Example 9: Generic function using trait
    println!("9. Generic indicator function:");
    fn describe_indicator<I: Indicator>(name: &str, ind: &I) 
    where
        I::Output: std::fmt::Display,
    {
        println!("   {}: {}", name, ind.get(0));
    }
    
    let base_ind = BaseIndicator::<f64, 1>::new_float();
    let mut ma_ind = MA::<3, 1>::new();
    ma_ind.update(5.0);
    ma_ind.update(10.0);
    ma_ind.update(15.0);
    
    describe_indicator("MA(3)", &ma_ind);
    
    println!("\n=== All indicators implemented successfully! ===");
}
