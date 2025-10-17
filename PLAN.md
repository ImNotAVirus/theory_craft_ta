# Plan d'implémentation des indicateurs TA-Lib

## Principes directeurs

1. **Référence**: Python ta-lib (comportement identique)
2. **nil pas NaN**: Python utilise NaN, on utilise nil en Elixir
3. **Types stricts**: integer(), pas de guards (FunctionClauseError naturel)
4. **Pas de validation extra**: Laisser TA-Lib gérer
5. **TDD strict**: Tests d'abord, basés sur Python ta-lib
6. **Calcul incrémental**: Fonction `_next` obligatoire avec état via ResourceArc
7. **0 warnings**: La compilation (Rust + Elixir) doit générer 0 warnings

## Méthodologie TDD (7 phases)

### Phase 1: TESTS FIRST

**Toujours commencer par tester avec Python ta-lib**

```bash
python -c "import talib; import numpy as np; ..."
```

Tester edge cases:
- ✅ Cas normal
- ✅ Period minimum/invalides (0, négatif)
- ✅ Period float (doit lever FunctionClauseError)
- ✅ Empty array
- ✅ Insufficient data
- ✅ Period == data length

Structure des tests dans `test/theory_craft_ta/*_test.exs`:
- Tests pour chaque backend (Native + Elixir)
- Tests pour chaque type (list, DataSeries, TimeSeries)
- Tests public API
- Property-based tests (Native vs Elixir)
- Tests pour `_next` (UPDATE et APPEND modes)

### Phase 2: Implémentation Elixir Backend

Fichier: `lib/theory_craft_ta/elixir/*.ex`

Règles:
- ❌ PAS de guards
- ✅ Validation dans le corps
- ✅ Retour {:error, message_explicite}
- ✅ Empty → {:ok, []} ou structure vide
- ✅ nil pour lookback

Messages d'erreur TA-Lib:
- Code 2 → "Invalid period: must be >= X for [INDICATOR]"
- Autres codes → voir implementation existante

### Phase 3: Implémentation Rust NIF

Fichier: `native/theory_craft_ta/src/*.rs`

Règles:
- ✅ Gérer empty array
- ❌ PAS de validation (laisser TA-Lib)
- ✅ Convertir NaN en None

### Phase 4: Wrapper Native

Fichier: `lib/theory_craft_ta/native/*.ex`

- SIMPLE: juste appeler NIF et reconstruire type
- ❌ PAS de validation

### Phase 5: Fonction `_next` avec État (ResourceArc)

**NOUVELLE APPROCHE** : Utiliser Rustler ResourceArc pour gérer l'état interne.

#### 5.1 Organisation du code Rust

**Fichiers** :
- `native/theory_craft_ta/src/overlap.rs` : Fonctions batch (TA-Lib FFI)
- `native/theory_craft_ta/src/overlap_state.rs` : Fonctions stateful pour streaming

**Nommage des fonctions** :
- `overlap_ema_state_init(period)` → Initialise l'état EMA
- `overlap_ema_state_next(state, value, is_new_bar)` → Calcule prochaine valeur avec état

**Gestion UPDATE vs APPEND** :
- `is_new_bar = false` (UPDATE) : Tick sur même bar → calcule EMA et met à jour l'état (car état final = dernier tick du bar)
- `is_new_bar = true` (APPEND) : Nouveau bar → calcule EMA avec état du dernier tick du bar précédent, puis met à jour

**IMPORTANT** : L'état est TOUJOURS mis à jour à chaque calcul. L'état final d'un bar = état du dernier tick exécuté dans ce bar.

#### 5.2 Structure d'état (Native backend - Rust)

Fichier: `native/theory_craft_ta/src/overlap_state.rs`

```rust
use rustler::ResourceArc;

pub struct EMAState {
    period: i32,
    k: f64,  // 2.0 / (period + 1.0)
    current_ema: Option<f64>,  // EMA actuel (mis à jour à chaque tick)
    lookback_count: i32,  // Nombre de bars vus jusqu'au dernier APPEND
}
```

**Logique `overlap_ema_state_next`** :
- Si `lookback_count < period` (phase de warmup) :
  - Si `is_new_bar = true` : increment `lookback_count`
  - Retourne `(None, état mis à jour)`
- Sinon :
  - Calcule `new_ema = (value - current_ema) * k + current_ema`
  - Met à jour `state.current_ema = new_ema`
  - Si `is_new_bar = true` : increment `lookback_count`
  - Retourne `(Some(new_ema), état mis à jour)`

#### 5.3 Implémentation Elixir backend avec état

Fichier: `lib/theory_craft_ta/elixir/state/ema.ex`

```elixir
defmodule TheoryCraftTA.Elixir.State.EMA do
  @moduledoc false

  defstruct [:period, :k, :current_ema, :lookback_count]

  @type t :: %__MODULE__{
    period: pos_integer(),
    k: float(),
    current_ema: float() | nil,
    lookback_count: non_neg_integer()
  }

  def init(period) do
    state = %__MODULE__{
      period: period,
      k: 2.0 / (period + 1.0),
      current_ema: nil,
      lookback_count: 0
    }

    {:ok, state}
  end

  def next(state, value, is_new_bar) do
    new_lookback = if is_new_bar, do: state.lookback_count + 1, else: state.lookback_count

    if new_lookback < state.period do
      # Phase de warmup
      new_state = %{state | lookback_count: new_lookback}
      {:ok, nil, new_state}
    else
      # Calcul EMA
      new_ema = if state.current_ema == nil do
        value  # Premier EMA = valeur
      else
        (value - state.current_ema) * state.k + state.current_ema
      end

      new_state = %{state | current_ema: new_ema, lookback_count: new_lookback}
      {:ok, new_ema, new_state}
    end
  end
end
```

#### 5.4 Wrapper Native backend avec ResourceArc

Fichier: `lib/theory_craft_ta/native/state/ema.ex`

```elixir
defmodule TheoryCraftTA.Native.State.EMA do
  @moduledoc false

  defstruct [:ref, :period]

  @type t :: %__MODULE__{
    ref: reference(),
    period: pos_integer()
  }

  def init(period) do
    # Appelle la NIF Rust qui retourne ResourceArc
    TheoryCraftTA.Native.Overlap.overlap_ema_state_init(period)
  end

  def next(state, value, is_new_bar) do
    # Appelle la NIF Rust avec ResourceArc
    TheoryCraftTA.Native.Overlap.overlap_ema_state_next(state, value, is_new_bar)
  end
end
```

#### 5.5 Tests property-based pour `_next` avec état

**Stratégie de test** : Vérifier que le calcul incrémental produit le même résultat que le calcul batch.

**Test 1 : APPEND mode (chaque valeur = nouveau bar)**

```elixir
property "state-based APPEND matches batch calculation" do
  check all(
    data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 100),
    period <- integer(2..20)
  ) do
    {:ok, batch_result} = TheoryCraftTA.ema(data, period)
    {:ok, state} = Backend.State.EMA.init(period)  # Backend = Elixir ou Native

    {_final_state, incremental_results} =
      Enum.reduce(data, {state, []}, fn value, {st, results} ->
        {:ok, ema_value, new_state} = Backend.State.EMA.next(st, value, true)  # is_new_bar = true
        {new_state, [ema_value | results]}
      end)

    incremental_results = Enum.reverse(incremental_results)
    assert_lists_equal(batch_result, incremental_results)
  end
end
```

**Test 2 : UPDATE mode (simuler plusieurs ticks sur même bar)**

```elixir
property "state-based UPDATE updates state continuously" do
  check all(
    data <- list_of(float(min: 1.0, max: 1000.0), min_length: 21, max_length: 100),
    period <- integer(2..20)
  ) do
    {:ok, state} = Backend.State.EMA.init(period)

    # Construire état avec les N premiers bars
    {state_after_n, _} = Enum.reduce(Enum.take(data, period + 5), {state, []}, fn value, {st, results} ->
      {:ok, ema_value, new_state} = Backend.State.EMA.next(st, value, true)  # APPEND
      {new_state, [ema_value | results]}
    end)

    # Simuler plusieurs ticks sur le même bar (UPDATE)
    test_value = Enum.at(data, period + 5)
    {:ok, ema1, state1} = Backend.State.EMA.next(state_after_n, test_value, false)  # UPDATE
    {:ok, ema2, state2} = Backend.State.EMA.next(state1, test_value + 1.0, false)  # UPDATE

    # État doit être mis à jour à chaque fois (current_ema change)
    assert state1.current_ema != state_after_n.current_ema
    assert state2.current_ema != state1.current_ema

    # Mais lookback_count ne change pas
    assert state1.lookback_count == state_after_n.lookback_count
    assert state2.lookback_count == state1.lookback_count

    # Valeurs EMA doivent être différentes
    assert ema1 != ema2
  end
end
```

#### 5.6 Intégration avec TheoryCraft.Indicator

L'état permet une intégration naturelle avec TheoryCraft.Indicator.

**Cas 1 : Processing Candles (bars) - is_new_bar toujours true**

```elixir
defmodule MyIndicators.EMA do
  @behaviour TheoryCraft.Indicator

  # Utiliser le backend configuré
  @backend Application.compile_env(:theory_craft_ta, :default_backend)
  @state_module Module.concat(@backend, State.EMA)

  @impl true
  def loopback(), do: 0  # Pas d'historique nécessaire

  @impl true
  def init(opts) do
    period = Keyword.fetch!(opts, :period)
    {:ok, ema_state} = @state_module.init(period)
    {:ok, %{ema_state: ema_state, output_name: "ema_#{period}"}}
  end

  @impl true
  def next(%MarketEvent{data: %Candle{close: close}} = event, state) do
    # Chaque Candle = nouveau bar → is_new_bar = true
    {:ok, ema_value, new_ema_state} = @state_module.next(state.ema_state, close, true)
    updated_event = put_in(event.data[state.output_name], ema_value)
    {:ok, updated_event, %{state | ema_state: new_ema_state}}
  end
end
```

**Cas 2 : Processing Ticks - détecter nouveau bar**

```elixir
defmodule MyIndicators.EMAOnTicks do
  @behaviour TheoryCraft.Indicator

  @backend Application.compile_env(:theory_craft_ta, :default_backend)
  @state_module Module.concat(@backend, State.EMA)

  @impl true
  def loopback(), do: 0

  @impl true
  def init(opts) do
    period = Keyword.fetch!(opts, :period)
    timeframe = Keyword.fetch!(opts, :timeframe)
    {:ok, ema_state} = @state_module.init(period)

    {:ok, %{
      ema_state: ema_state,
      output_name: "ema_#{period}",
      timeframe: timeframe,
      current_bar_time: nil  # Timestamp du bar actuel
    }}
  end

  @impl true
  def next(%MarketEvent{data: %Tick{time: time, ask: ask, bid: bid}} = event, state) do
    close = (ask + bid) / 2.0
    bar_time = TheoryCraft.TimeFrame.floor(time, state.timeframe)

    # Nouveau bar si bar_time différent de current_bar_time
    is_new_bar = state.current_bar_time == nil || bar_time != state.current_bar_time

    {:ok, ema_value, new_ema_state} = @state_module.next(state.ema_state, close, is_new_bar)
    updated_event = put_in(event.data[state.output_name], ema_value)

    new_state = %{state |
      ema_state: new_ema_state,
      current_bar_time: bar_time
    }

    {:ok, updated_event, new_state}
  end
end
```

### Phase 6: Benchmarking

Fichier: `benchmarks/<indicator>_benchmark.exs`

Structure:
- 3 tailles: small (100), medium (1K), large (10K)
- 3 types: List, DataSeries, TimeSeries
- 2 backends: Native, Elixir
- Fonction base + `_next` (APPEND + UPDATE)

### Phase 7: Vérification

1. **Tests**: `.tools/setup_env.cmd`
   - 0 failures
   - Compilation Rust sans warnings

2. **Benchmark**: `.tools/run_benchmark.cmd benchmarks/<indicator>_benchmark.exs`
   - Native > Elixir pour gros datasets
   - Pour petits `_next`: Elixir peut être plus rapide (NIF overhead)

## Catégories d'indicateurs

### 1. Overlap Studies
SMA, EMA, WMA, DEMA, TEMA, TRIMA, KAMA, MAMA, T3, BBANDS, MIDPOINT, MIDPRICE, SAR, SAREXT, HT_TRENDLINE

### 2. Momentum Indicators
ADX, ADXR, APO, AROON, AROONOSC, BOP, CCI, CMO, DX, MACD, MACDEXT, MACDFIX, MFI, MINUS_DI, MINUS_DM, MOM, PLUS_DI, PLUS_DM, PPO, ROC, ROCP, ROCR, ROCR100, RSI, STOCH, STOCHF, STOCHRSI, TRIX, ULTOSC, WILLR

### 3. Volume Indicators
AD, ADOSC, OBV

### 4. Volatility Indicators
ATR, NATR, TRANGE

### 5. Price Transform
AVGPRICE, MEDPRICE, TYPPRICE, WCLPRICE

### 6. Cycle Indicators
HT_DCPERIOD, HT_DCPHASE, HT_PHASOR, HT_SINE, HT_TRENDMODE

### 7. Pattern Recognition
CDL* (tous les patterns)

### 8. Statistic Functions
BETA, CORREL, LINEARREG, LINEARREG_ANGLE, LINEARREG_INTERCEPT, LINEARREG_SLOPE, STDDEV, TSF, VAR

### 9. Math Transform
ACOS, ASIN, ATAN, CEIL, COS, COSH, EXP, FLOOR, LN, LOG10, SIN, SINH, SQRT, TAN, TANH

### 10. Math Operators
ADD, DIV, MAX, MAXINDEX, MIN, MININDEX, MINMAX, MINMAXINDEX, MULT, SUB, SUM

## Checklist par indicateur

- [ ] Tests basés sur Python ta-lib
- [ ] Edge cases testés
- [ ] Implémentation Elixir
- [ ] Implémentation Rust NIF
- [ ] Wrapper Native
- [ ] Tests passent (2 backends)
- [ ] Property-based tests
- [ ] Fonction `_next` avec état (ResourceArc)
- [ ] Tests pour `_next` (UPDATE/APPEND)
- [ ] Property-based tests pour `_next`
- [ ] Benchmark créé
- [ ] Vérification avec scripts
- [ ] `mix format`
- [ ] Vérification vs Python

## Notes importantes

- **État pour `_next`**: Utiliser ResourceArc pour indicateurs avec mémoire (EMA, DEMA, MACD, RSI, etc.)
- **Indicateurs sans état**: SMA, simple math transforms peuvent utiliser l'approche actuelle
- **NIF overhead**: Pour petits calculs `_next`, Elixir peut être plus rapide
- **TA-Lib range**: SMA peut optimiser avec `start_idx = end_idx`, pas EMA (stateful)
