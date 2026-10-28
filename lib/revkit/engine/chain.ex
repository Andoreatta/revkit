defmodule Revkit.Engine.Chain do
  @moduledoc """
  Applies an ordered list of transforms to a payload.

  Each step is `{module, options}`. Evaluation halts at the first error and
  returns it unchanged, so callers see the original transform error term.
  """

  alias Revkit.Transform

  @typedoc "A transform module paired with its per-step options."
  @type step :: {module(), Transform.options()}

  @doc """
  Runs `steps` against `input` in order.

  An empty list returns the input unchanged. A transform that returns a
  non-binary success is rejected with `{:error, {:invalid_transform_result,
  module, result}}` instead of leaking a non-binary value into the chain.
  """
  @spec run(String.t(), [step()]) :: Transform.result()
  def run(input, steps) when is_binary(input) and is_list(steps) do
    Enum.reduce_while(steps, {:ok, input}, fn {module, options}, {:ok, acc} ->
      case module.apply(acc, options) do
        {:ok, next} when is_binary(next) -> {:cont, {:ok, next}}
        {:error, _reason} = error -> {:halt, error}
        other -> {:halt, {:error, {:invalid_transform_result, module, other}}}
      end
    end)
  end
end
