# Plan d'implémentation des indicateurs TA-Lib

## Contexte

TheoryCraftTA est un wrapper Elixir autour de TA-Lib (Technical Analysis Library).
Le but est d'implémenter TOUS les indicateurs présents dans TA-Lib avec une double implémentation:
- **Native (Rust NIF)**: Utilise TA-Lib C via FFI pour la performance
- **Elixir pur**: Implémentation de secours, utile pour le développement et les tests

## Principes directeurs

1. **Comportement identique à Python ta-lib**: Le wrapper Python est notre référence
2. **nil en Elixir, pas NaN**: Python utilise NaN, on adapte avec nil
3. **Types stricts**: integer(), non_neg_integer() ou pos_integer() dans les specs, pas de guards (laisser FunctionClauseError)
4. **Pas de validation supplémentaire**: Laisser TA-Lib gérer les erreurs
5. **TDD strict**: Tests d'abord, basés sur Python ta-lib
6. **Calcul incrémental**: Chaque indicateur a une fonction `_next` pour usage streaming

## Méthodologie TDD pour chaque indicateur

### Phase 1: TESTS FIRST

**TOUJOURS commencer par les tests avant toute implémentation**

#### 1.1 Recherche du comportement Python

Pour chaque indicateur, exécuter Python ta-lib pour comprendre:

```bash
# Exemple pour SMA
python -c "import talib; import numpy as np; \
  data = np.array([1.0, 2.0, 3.0, 4.0, 5.0]); \
  print('period=3:', talib.SMA(data, 3))"
```

Tester TOUS les edge cases:
- ✅ Cas normal (plusieurs periods)
- ✅ Period minimum valide
- ✅ Period invalides (0, négatif, trop petit)
- ✅ Period float (doit lever FunctionClauseError en Elixir)
- ✅ Empty array
- ✅ Insufficient data (period > data length)
- ✅ Period == data length

#### 1.2 Écrire les tests Elixir

Structure des tests dans `test/theory_craft_ta/overlap_test.exs`:

```elixir
@backends %{
  native: TheoryCraftTA.Native.Overlap,
  elixir: TheoryCraftTA.Elixir.Overlap
}

for {backend_name, backend_module} <- @backends do
  @backend_module backend_module

  describe "#{backend_name} - sma/2 with list input" do
    test "calculates correctly with period=3" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      # Python result: [nan nan 2. 3. 4.]
      assert {:ok, result} = @backend_module.sma(data, 3)
      assert result == [nil, nil, 2.0, 3.0, 4.0]
    end

    test "handles period=2 (minimum valid)" do
      data = [1.0, 2.0, 3.0, 4.0, 5.0]
      # Python result: [nan 1.5 2.5 3.5 4.5]
      assert {:ok, result} = @backend_module.sma(data, 2)
      assert result == [nil, 1.5, 2.5, 3.5, 4.5]
    end

    test "raises for period=1" do
      data = [1.0, 2.0, 3.0]
      # Python raises with error code 2 (BadParam)
      assert {:error, reason} = @backend_module.sma(data, 1)
      assert reason =~ "TA-Lib error code: 2"
    end

    test "raises FunctionClauseError for float period" do
      data = [1.0, 2.0, 3.0]
      assert_raise FunctionClauseError, fn ->
        @backend_module.sma(data, 2.5)
      end
    end

    test "returns empty for empty input" do
      # Python result: []
      assert {:ok, []} = @backend_module.sma([], 3)
    end

    test "handles insufficient data" do
      data = [1.0, 2.0]
      # Python with period=5: [nan nan]
      assert {:ok, result} = @backend_module.sma(data, 5)
      assert result == [nil, nil]
    end
  end

  # Tests pour DataSeries
  describe "#{backend_name} - sma/2 with DataSeries input" do
    # ...
  end

  # Tests pour TimeSeries
  describe "#{backend_name} - sma/2 with TimeSeries input" do
    # ...
  end
end
```

#### 1.3 Tests publics et property-based

```elixir
describe "TheoryCraftTA.sma/2 - public API" do
  test "delegates to configured backend" do
    # ...
  end
end

describe "property-based testing: Native vs Elixir backends" do
  property "produce identical results" do
    check all(
      data <- list_of(float(min: 1.0, max: 1000.0), min_length: 2, max_length: 100),
      period <- integer(2..10)  # Ajuster selon l'indicateur
    ) do
      {:ok, native_result} = TheoryCraftTA.Native.Overlap.sma(data, period)
      {:ok, elixir_result} = TheoryCraftTA.Elixir.Overlap.sma(data, period)
      assert_lists_equal(native_result, elixir_result)
    end
  end
end
```

### Phase 2: IMPLÉMENTATION Elixir Backend

**Fichier**: `lib/theory_craft_ta/elixir/overlap.ex`

Règles:
- ❌ PAS de guards sur les fonctions
- ✅ Validation dans le corps de fonction
- ✅ Retourner {:error, message_explicite} (pas de codes d'erreur)
- ✅ Empty data → {:ok, []} ou {:ok, structure_vide}
- ✅ Utiliser nil pour les valeurs de lookback

**Messages d'erreur TA-Lib**:
- Code 2 (BadParam) → "Invalid period: must be >= 2 for SMA" (adapter par indicateur)
- Code 3 (AllocErr) → "Memory allocation failed"
- Code 11 (OutOfRangeStartIndex) → "Start index out of range"
- Code 12 (OutOfRangeEndIndex) → "End index out of range"
- Autres codes → "TA-Lib internal error: [description]"

```elixir
@spec sma(TheoryCraftTA.source(), integer()) ::
        {:ok, TheoryCraftTA.source()} | {:error, String.t()}
def sma(data, period) do
  # Pas de guard - FunctionClauseError naturel si period n'est pas integer

  list_data = Helpers.to_list_and_reverse(data)

  # Empty data retourne vide (comme Python)
  if length(list_data) == 0 do
    {:ok, Helpers.rebuild_same_type(data, [])}
  else
    # Validation period (comme TA-Lib)
    if period < 2 do  # Ajuster selon l'indicateur
      {:error, "TA-Lib error code: 2"}  # BadParam
    else
      result = calculate_sma(list_data, period)
      {:ok, Helpers.rebuild_same_type(data, result)}
    end
  end
end

# Private calculation
defp calculate_sma(data, period) do
  data_length = length(data)

  # Cas: pas assez de données
  if data_length < period do
    List.duplicate(nil, data_length)
  else
    # Calcul normal
    sma_values =
      data
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(&calculate_average/1)

    lookback = period - 1
    List.duplicate(nil, lookback) ++ sma_values
  end
end

defp calculate_average(values) do
  Enum.sum(values) / length(values)
end
```

### Phase 3: IMPLÉMENTATION Rust NIF

**Fichier**: `native/theory_craft_ta/src/overlap.rs`

Règles:
- ✅ Gérer empty array explicitement
- ❌ PAS de validation de period (laisser TA-Lib)
- ✅ Retourner les erreurs TA-Lib correctement
- ✅ Convertir NaN en None pour Elixir

```rust
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_sma(env: Env, data: Vec<f64>, period: i32) -> NifResult<Term> {
    use talib_ffi::{TARetCode, TA_SMA_Lookback, TA_SMA};

    // Empty data → retourner vide (comme Python)
    if data.is_empty() {
        let success = (atoms::ok(), Vec::<Option<f64>>::new());
        return Ok(success.encode(env));
    }

    let data_len = data.len() as i32;
    let lookback = unsafe { TA_SMA_Lookback(period) };

    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let mut out_real: Vec<f64> = vec![0.0; data_len as usize];

    // Appel TA-Lib (peut échouer pour period invalide)
    let ret_code = unsafe {
        TA_SMA(
            0,
            data_len - 1,
            data.as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    // Retourner l'erreur si TA-Lib échoue
    if ret_code != TARetCode::Success as i32 {
        let err = (atoms::error(), format!("TA-Lib error code: {}", ret_code));
        return Ok(err.encode(env));
    }

    // Build result avec nil pour lookback
    let mut result: Vec<Option<f64>> = Vec::with_capacity(data_len as usize);

    // Lookback period → nil
    let num_nils = std::cmp::min(lookback, data_len);
    for _ in 0..num_nils {
        result.push(None);
    }

    // Valeurs calculées
    for i in 0..out_nb_element {
        result.push(Some(out_real[i as usize]));
    }

    let success = (atoms::ok(), result);
    Ok(success.encode(env))
}
```

### Phase 4: WRAPPER Native

**Fichier**: `lib/theory_craft_ta/native/overlap.ex`

Le wrapper doit être SIMPLE:
- ❌ PAS de validation
- ✅ Juste appeler le NIF et reconstruire le type

```elixir
@spec sma(TheoryCraftTA.source(), integer()) ::
        {:ok, TheoryCraftTA.source()} | {:error, String.t()}
def sma(data, period) do
  list_data = Helpers.to_list_and_reverse(data)

  case Native.overlap_sma(list_data, period) do
    {:ok, result_list} ->
      {:ok, Helpers.rebuild_same_type(data, result_list)}

    {:error, _reason} = error ->
      error
  end
end
```

### Phase 5: IMPLÉMENTATION Fonction `_next` (Calcul incrémental)

Chaque indicateur doit avoir une fonction `_next` pour calcul streaming.

**Comportement**:
- Si `length(input) == length(prev)`: UPDATE la dernière valeur (même bar, tick update)
- Si `length(input) > length(prev)`: AJOUTE une nouvelle valeur (nouvelle bar)

**Optimisations**:
- Utiliser `DataSeries.size/1` et `TimeSeries.size/1` (O(1) vs O(n))
- Modifier directement le champ `data` pour éviter les copies

**Fichier**: `lib/theory_craft_ta/elixir/overlap.ex`

```elixir
@doc """
Incremental SMA calculation - adds or updates the next value.

When streaming data, this function efficiently calculates the next SMA value
without reprocessing the entire dataset.

## Behavior
  - If `length(input) == length(prev)`: Updates last value (same bar, multiple ticks)
  - If `length(input) > length(prev)`: Adds new value (new bar)

## Parameters
  - `data` - Input data (must have one more element than prev, or same length)
  - `period` - Number of periods for the moving average
  - `prev` - Previous SMA result

## Returns
  - `{:ok, result}` with updated SMA values
  - `{:error, reason}` if validation fails

## Examples
    iex> TheoryCraftTA.Elixir.Overlap.sma_next([1.0, 2.0, 3.0, 4.0, 5.0], 2, [nil, 1.5, 2.5, 3.5])
    {:ok, [nil, 1.5, 2.5, 3.5, 4.5]}

    iex> TheoryCraftTA.Elixir.Overlap.sma_next([1.0, 2.0, 3.0, 4.0, 5.5], 2, [nil, 1.5, 2.5, 3.5, 4.5])
    {:ok, [nil, 1.5, 2.5, 3.5, 4.75]}

"""
@spec sma_next(TheoryCraftTA.source(), integer(), TheoryCraftTA.source()) ::
        {:ok, TheoryCraftTA.source()} | {:error, String.t()}
def sma_next(data, period, prev) do
  input_size = get_size(data)
  prev_size = get_size(prev)

  cond do
    input_size == prev_size ->
      # Update mode: recalculate last value
      update_last_sma(data, period, prev)

    input_size == prev_size + 1 ->
      # Append mode: calculate new value
      append_new_sma(data, period, prev)

    true ->
      {:error, "Input size must be equal to or one more than prev size"}
  end
end

## Private functions

defp get_size(data) when is_list(data), do: length(data)
defp get_size(%DataSeries{} = ds), do: DataSeries.size(ds)
defp get_size(%TimeSeries{} = ts), do: TimeSeries.size(ts)

defp update_last_sma(data, period, prev) do
  list_data = Helpers.to_list_and_reverse(data)
  prev_list = Helpers.to_list_and_reverse(prev)

  # Calculate new SMA for last position
  last_values = Enum.take(list_data, -period)
  new_sma = if length(last_values) == period do
    calculate_average(last_values)
  else
    nil
  end

  # Replace last value in prev
  updated = List.replace_at(prev_list, -1, new_sma)
  {:ok, Helpers.rebuild_same_type(data, updated)}
end

defp append_new_sma(data, period, prev) do
  list_data = Helpers.to_list_and_reverse(data)
  prev_list = Helpers.to_list_and_reverse(prev)

  # Calculate SMA for new position
  last_values = Enum.take(list_data, -period)
  new_sma = if length(last_values) == period do
    calculate_average(last_values)
  else
    nil
  end

  # Append new value
  updated = prev_list ++ [new_sma]
  {:ok, Helpers.rebuild_same_type(data, updated)}
end
```

**Fichier Rust NIF**: `native/theory_craft_ta/src/overlap.rs`

**Stratégie d'optimisation pour `_next`**:
- TA-Lib permet de calculer une range spécifique avec `start_idx` et `end_idx`
- Pour calcul incrémental, on a besoin uniquement de la **dernière valeur**
- Optimisation: `start_idx = end_idx` pour calculer seulement 1 élément
- Allocation minimale: `vec![0.0; 1]` au lieu de `vec![0.0; period]`

```rust
#[cfg(has_talib)]
#[rustler::nif]
pub fn overlap_sma_next(
    env: Env,
    data: Vec<f64>,
    period: i32,
    prev: Vec<Option<f64>>,
) -> NifResult<Term> {
    use talib_ffi::{TARetCode, TA_SMA};

    let data_len = data.len();
    let prev_len = prev.len();

    if data_len == 0 {
        let success = (atoms::ok(), Vec::<Option<f64>>::new());
        return Ok(success.encode(env));
    }

    // Detect update vs append mode
    let should_update = data_len == prev_len;
    let should_append = data_len == prev_len + 1;

    if !should_update && !should_append {
        let err = (
            atoms::error(),
            "Input size must be equal to or one more than prev size",
        );
        return Ok(err.encode(env));
    }

    // Calculate ONLY the last value using TA-Lib's range feature
    let end_idx = (data_len - 1) as i32;
    let start_idx = end_idx;  // Key optimization: only calculate 1 value

    let mut out_beg_idx: i32 = 0;
    let mut out_nb_element: i32 = 0;
    let mut out_real: Vec<f64> = vec![0.0; 1];  // Only allocate 1 element

    let ret_code = unsafe {
        TA_SMA(
            start_idx,
            end_idx,
            data.as_ptr(),
            period,
            &mut out_beg_idx as *mut i32,
            &mut out_nb_element as *mut i32,
            out_real.as_mut_ptr(),
        )
    };

    if ret_code != TARetCode::Success as i32 {
        // Handle error codes...
        let err = (atoms::error(), "TA-Lib error");
        return Ok(err.encode(env));
    }

    // Extract the single calculated value
    let new_sma = if out_nb_element > 0 {
        Some(out_real[0])
    } else {
        None
    };

    // Update or append based on mode
    let result = if should_update {
        let mut updated = prev.clone();
        if let Some(last) = updated.last_mut() {
            *last = new_sma;
        }
        updated
    } else {
        let mut appended = prev.clone();
        appended.push(new_sma);
        appended
    };

    let success = (atoms::ok(), result);
    Ok(success.encode(env))
}
```

**Fichier**: `lib/theory_craft_ta.ex` (Public API)

```elixir
@doc """
Incremental SMA calculation.

## Examples
    iex> TheoryCraftTA.sma_next([1.0, 2.0, 3.0, 4.0, 5.0], 2, [nil, 1.5, 2.5, 3.5])
    {:ok, [nil, 1.5, 2.5, 3.5, 4.5]}

"""
@spec sma_next(source(), integer(), source()) :: {:ok, source()} | {:error, String.t()}
defdelegate sma_next(data, period, prev), to: Module.concat(@backend, Overlap)

@doc """
Incremental SMA calculation - Bang version.

## Examples
    iex> TheoryCraftTA.sma_next!([1.0, 2.0, 3.0, 4.0, 5.0], 2, [nil, 1.5, 2.5, 3.5])
    [nil, 1.5, 2.5, 3.5, 4.5]

"""
@spec sma_next!(source(), integer(), source()) :: source()
def sma_next!(data, period, prev) do
  case sma_next(data, period, prev) do
    {:ok, result} -> result
    {:error, reason} -> raise "SMA_next error: #{reason}"
  end
end
```

### Phase 6: BENCHMARKING

Créer un fichier de benchmark pour comparer les performances Native vs Elixir.

**Fichier**: `benchmarks/<indicator>_benchmark.exs`

Structure du benchmark:
- Tester plusieurs tailles de datasets (small: 100, medium: 1K, large: 10K)
- Tester avec des listes ET DataSeries
- Tester la fonction de base ET la fonction `_next`
- Pour `_next`: tester les deux modes (APPEND et UPDATE)

```elixir
alias TheoryCraft.DataSeries
alias TheoryCraftTA.Native.Overlap, as: NativeTA
alias TheoryCraftTA.Elixir.Overlap, as: ElixirTA

# Generate test data
small_data = Enum.map(1..100, &(&1 * 1.0))
medium_data = Enum.map(1..1_000, &(&1 * 1.0))
large_data = Enum.map(1..10_000, &(&1 * 1.0))

# Prepare for sma_next benchmarks
small_prev_data = Enum.take(small_data, 99)
{:ok, small_prev_native} = NativeTA.sma(small_prev_data, 10)
{:ok, small_prev_elixir} = ElixirTA.sma(small_prev_data, 10)

# Benchmark base function
IO.puts("\n=== Small Dataset (100 items) ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeTA.sma(small_data, 10) end,
    "Elixir List" => fn -> ElixirTA.sma(small_data, 10) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

# Benchmark _next function - APPEND mode
IO.puts("\n=== SMA_NEXT - Small Dataset (100 items) - APPEND MODE ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeTA.sma_next(small_data, 10, small_prev_native) end,
    "Elixir List" => fn -> ElixirTA.sma_next(small_data, 10, small_prev_elixir) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)

# Benchmark _next function - UPDATE mode
small_updated_data = List.replace_at(small_data, -1, 999.0)
{:ok, small_current_native} = NativeTA.sma(small_data, 10)
{:ok, small_current_elixir} = ElixirTA.sma(small_data, 10)

IO.puts("\n=== SMA_NEXT - Small Dataset (100 items) - UPDATE MODE ===\n")

Benchee.run(
  %{
    "Native List" => fn -> NativeTA.sma_next(small_updated_data, 10, small_current_native) end,
    "Elixir List" => fn -> ElixirTA.sma_next(small_updated_data, 10, small_current_elixir) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2,
  formatters: [Benchee.Formatters.Console]
)
```

**Exécution**:
```bash
# Lancer le benchmark
mix run benchmarks/sma_benchmark.exs
```

### Phase 7: VÉRIFICATION

1. **Lancer les tests**:
   ```bash
   MIX_ENV=test mix test
   ```

2. **Vérifier que Native et Elixir sont cohérents**:
   - Property-based tests doivent passer
   - Tous les edge cases doivent être gérés identiquement

3. **Comparer avec Python ta-lib**:
   ```bash
   # Pour chaque test, vérifier manuellement avec Python
   python -c "import talib; import numpy as np; ..."
   ```

4. **Lancer le benchmark**:
   ```bash
   mix run benchmarks/<indicator>_benchmark.exs
   ```
   - Vérifier que Native est significativement plus rapide qu'Elixir
   - Vérifier que `_next` est plus rapide que recalculer tout l'indicateur

## Catégories d'indicateurs

Les indicateurs TA-Lib sont divisés en 5 catégories:

### 1. Overlap Studies (Études de chevauchement)
- SMA (Simple Moving Average)
- EMA (Exponential Moving Average)
- WMA (Weighted Moving Average)
- DEMA (Double Exponential Moving Average)
- TEMA (Triple Exponential Moving Average)
- TRIMA (Triangular Moving Average)
- KAMA (Kaufman Adaptive Moving Average)
- MAMA (MESA Adaptive Moving Average)
- T3 (Triple Exponential Moving Average)
- BBANDS (Bollinger Bands)
- MIDPOINT (MidPoint over period)
- MIDPRICE (Midpoint Price over period)
- SAR (Parabolic SAR)
- SAREXT (Parabolic SAR - Extended)
- HT_TRENDLINE (Hilbert Transform - Instantaneous Trendline)

### 2. Momentum Indicators (Indicateurs de momentum)
- ADX (Average Directional Movement Index)
- ADXR (Average Directional Movement Index Rating)
- APO (Absolute Price Oscillator)
- AROON (Aroon)
- AROONOSC (Aroon Oscillator)
- BOP (Balance Of Power)
- CCI (Commodity Channel Index)
- CMO (Chande Momentum Oscillator)
- DX (Directional Movement Index)
- MACD (Moving Average Convergence/Divergence)
- MACDEXT (MACD with controllable MA type)
- MACDFIX (Moving Average Convergence/Divergence Fix 12/26)
- MFI (Money Flow Index)
- MINUS_DI (Minus Directional Indicator)
- MINUS_DM (Minus Directional Movement)
- MOM (Momentum)
- PLUS_DI (Plus Directional Indicator)
- PLUS_DM (Plus Directional Movement)
- PPO (Percentage Price Oscillator)
- ROC (Rate of change)
- ROCP (Rate of change Percentage)
- ROCR (Rate of change ratio)
- ROCR100 (Rate of change ratio 100 scale)
- RSI (Relative Strength Index)
- STOCH (Stochastic)
- STOCHF (Stochastic Fast)
- STOCHRSI (Stochastic Relative Strength Index)
- TRIX (1-day Rate-Of-Change (ROC) of a Triple Smooth EMA)
- ULTOSC (Ultimate Oscillator)
- WILLR (Williams' %R)

### 3. Volume Indicators (Indicateurs de volume)
- AD (Chaikin A/D Line)
- ADOSC (Chaikin A/D Oscillator)
- OBV (On Balance Volume)

### 4. Volatility Indicators (Indicateurs de volatilité)
- ATR (Average True Range)
- NATR (Normalized Average True Range)
- TRANGE (True Range)

### 5. Price Transform (Transformation de prix)
- AVGPRICE (Average Price)
- MEDPRICE (Median Price)
- TYPPRICE (Typical Price)
- WCLPRICE (Weighted Close Price)

### 6. Cycle Indicators (Indicateurs de cycle)
- HT_DCPERIOD (Hilbert Transform - Dominant Cycle Period)
- HT_DCPHASE (Hilbert Transform - Dominant Cycle Phase)
- HT_PHASOR (Hilbert Transform - Phasor Components)
- HT_SINE (Hilbert Transform - SineWave)
- HT_TRENDMODE (Hilbert Transform - Trend vs Cycle Mode)

### 7. Pattern Recognition (Reconnaissance de motifs)
- Tous les patterns de chandeliers (CDL*)

### 8. Statistic Functions (Fonctions statistiques)
- BETA (Beta)
- CORREL (Pearson's Correlation Coefficient)
- LINEARREG (Linear Regression)
- LINEARREG_ANGLE (Linear Regression Angle)
- LINEARREG_INTERCEPT (Linear Regression Intercept)
- LINEARREG_SLOPE (Linear Regression Slope)
- STDDEV (Standard Deviation)
- TSF (Time Series Forecast)
- VAR (Variance)

### 9. Math Transform (Transformations mathématiques)
- ACOS, ASIN, ATAN, CEIL, COS, COSH, EXP, FLOOR, LN, LOG10, SIN, SINH, SQRT, TAN, TANH

### 10. Math Operators (Opérateurs mathématiques)
- ADD, DIV, MAX, MAXINDEX, MIN, MININDEX, MINMAX, MINMAXINDEX, MULT, SUB, SUM

## Structure des fichiers

```
lib/theory_craft_ta/
├── native/
│   └── overlap.ex          # Native wrapper pour Overlap
├── elixir/
│   └── overlap.ex          # Implémentation Elixir pure
└── helpers.ex              # Fonctions utilitaires

native/theory_craft_ta/src/
└── overlap.rs              # NIF Rust

test/theory_craft_ta/
└── overlap_test.exs        # Tests pour Overlap (Native + Elixir)
```

## Code Guidelines appliquées

- Section comments: `## Public API`, `## Private functions`
- @moduledoc pour tous les modules publics
- @moduledoc """ suivi d'une ligne blanche pour private modules avec commentaires
- @doc + @spec + exemples pour toutes les fonctions publiques
- Ligne blanche avant le return dans les fonctions > 3 lignes
- Séparation des blocs logiques avec lignes blanches
- Pattern matching dans le corps pour les champs non-flow
- Pas de tuples multilignes
- Préserver microsecond precision dynamiquement
- Utiliser struct types explicites pour updates

## Checklist par indicateur

- [ ] Tests écrits basés sur Python ta-lib
- [ ] Edge cases testés (empty, invalid params, etc.)
- [ ] Implémentation Elixir backend
- [ ] Implémentation Rust NIF
- [ ] Wrapper Native simplifié
- [ ] Tests passent pour les deux backends
- [ ] Property-based tests (Native vs Elixir)
- [ ] Fonction `_next` implémentée (calcul incrémental)
- [ ] Implémentation Rust NIF pour `_next` (optimisée avec range feature)
- [ ] Tests pour `_next` (update et append modes)
- [ ] Property-based tests pour `_next` (Native vs Elixir)
- [ ] Benchmark créé dans `benchmarks/<indicator>_benchmark.exs`
- [ ] Benchmark pour fonction de base (small, medium, large datasets)
- [ ] Benchmark pour fonction `_next` (APPEND et UPDATE modes)
- [ ] Documentation complète
- [ ] Formatage avec `mix format`
- [ ] Vérification manuelle vs Python ta-lib
