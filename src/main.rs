use tzutrader::indicators::{Indicator, MA};
use tzutrader::types::Ohlcv;

fn main() {
    // Test MA indicator
    println!("=== Moving Average Example ===");
    let mut ma = MA::<5, 3>::new();
    for i in 1..=10 {
        ma.update(i as f64);
    }
    println!("Current: {:.2}", ma.get(0).unwrap_or(f64::NAN));
    println!("Previous: {:.2}", ma.get(-1).unwrap_or(f64::NAN));
    println!("Two bars ago: {:.2}\n", ma.get(-2).unwrap_or(f64::NAN));

    // Test Ohlcv type
    println!("=== OHLCV Data Type Example ===");
    let bar = Ohlcv::new(1609459200000, 100.0, 105.0, 99.0, 103.0, 10000.0);
    println!(
        "Bar: Open={}, High={}, Low={}, Close={}, Volume={}",
        bar.open, bar.high, bar.low, bar.close, bar.volume
    );
    println!("Typical Price: {:.2}", bar.typical_price());
    println!("Median Price: {:.2}", bar.median_price());
    println!("Is Bullish: {}", bar.is_bullish());
    println!("Body Size: {:.2}", bar.body_size());
    println!("Range: {:.2}", bar.range());
}
