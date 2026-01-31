# TzuTrader build configuration
# This file sets default compilation flags for the project

# Enable Yahoo Finance support by default
switch("define", "useYfnim")

# Enable SSL for HTTPS requests to Yahoo Finance
switch("define", "ssl")

# Note: These flags ensure deterministic, reproducible backtests
# by fetching real historical data from Yahoo Finance instead of
# using mock random data.
