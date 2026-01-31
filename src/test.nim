import tzutrader/datastreamers

let data = streamYahoo[OHLCV]("AAPL", "2023-01-01", "2023-12-31")
for bar in data.items():
  echo bar
