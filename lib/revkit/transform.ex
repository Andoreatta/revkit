defmodule Revkit.Transform do
  @moduledoc """
  Contract for a single, pure step in a payload transformation chain.

  A transform maps a binary plus an options map to either the transformed
  binary or an error. Implementations must not perform IO, touch the database,
  start processes, call `System.cmd/3`, or execute the payload. Inputs and
  outputs are plain strings, which keeps the engine cheap to preview and easy
  to test.
  """

  @typedoc "Category used to group transforms in the UI."
  @type kind :: :encoding | :wrapper

  @typedoc "Per-step options. Transforms must tolerate an empty map."
  @type options :: %{optional(atom()) => term()}

  @typedoc "Result of applying a transform or a chain."
  @type result :: {:ok, String.t()} | {:error, term()}

  @doc "Stable identifier, unique across transforms."
  @callback key() :: atom()

  @doc "Human-readable label for the UI."
  @callback label() :: String.t()

  @doc "Category used to group transforms in the UI."
  @callback kind() :: kind()

  @doc "Applies the transform to `input` without side effects."
  @callback apply(input :: String.t(), options()) :: result()

  @doc "Prerequisites on the target environment."
  @callback requires() :: [String.t()]

  @doc "Warnings about reversibility or limitations of the transform."
  @callback pitfalls() :: [String.t()]
end
