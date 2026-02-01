## Declarative Strategy System
##
## This module provides the declarative YAML-based strategy definition system.
## It allows traders to define strategies without writing Nim code.
##
## The declarative system consists of several components:
##
## Schema and Parsing
## ==================
##
## - `schema`: Data structures for strategy definitions
## - `parser`: YAML parsing and deserialization
## - `validator`: Validation of strategy definitions
##
## Strategy Building
## =================
##
## - `strategy_builder`: Convert declarative definitions to executable strategies
## - `expression`: Expression evaluation for dynamic values
## - `condition_eval`: Condition evaluation for buy/sell signals
##
## Risk Management and Position Sizing
## ====================================
##
## - `risk_management`: Stop-loss and take-profit rules
## - `position_sizing`: Position sizing strategies (fixed, percent, risk-based)
##
## Batch Processing and Parameter Sweeps
## ======================================
##
## - `batch_runner`: Run multiple strategies/symbols in batch
## - `sweep_runner`: Parameter optimization via grid search
## - `sweep_generator`: Generate parameter combinations
## - `results`: Aggregate and analyze batch results
##
## Usage
## =====
##
## The declarative system is primarily used through:
##
## 1. **YAML files** - Define strategies in `.yaml` files
## 2. **CLI tool** - The `tzu` command-line tool for running YAML strategies
## 3. **Programmatic API** - Import these modules directly for custom workflows
##
## Example YAML Strategy
## =====================
##
## .. code-block:: yaml
##   name: "RSI Mean Reversion"
##   description: "Buy oversold, sell overbought"
##   
##   indicators:
##     - id: rsi
##       type: RSI
##       params:
##         period: 14
##   
##   buy_conditions:
##     operator: "<"
##     left: rsi
##     right: 30
##   
##   sell_conditions:
##     operator: ">"
##     left: rsi
##     right: 70
##   
##   risk_management:
##     stop_loss:
##       type: fixed_percent
##       percent: 5.0
##     take_profit:
##       type: fixed_percent
##       percent: 10.0
##
## See Also
## ========
##
## - User Guide: `Writing Custom Strategies with YAML <../user_guide/04b_custom_strategies_yaml.html>`_
## - Reference: `Declarative YAML Interface <../reference_guide/10_declarative.html>`_
## - Examples: Check the `examples/yaml_strategies/` directory

import tzutrader/declarative/schema
import tzutrader/declarative/parser
import tzutrader/declarative/validator
import tzutrader/declarative/strategy_builder
import tzutrader/declarative/expression
import tzutrader/declarative/condition_eval
import tzutrader/declarative/risk_management
import tzutrader/declarative/position_sizing
import tzutrader/declarative/batch_runner
import tzutrader/declarative/sweep_generator
import tzutrader/declarative/sweep_runner
import tzutrader/declarative/results

export schema, parser, validator, strategy_builder, expression, condition_eval
export risk_management, position_sizing, batch_runner, sweep_generator, sweep_runner, results
