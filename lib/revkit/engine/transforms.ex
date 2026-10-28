defmodule Revkit.Engine.Transforms do
  @moduledoc """
  Registry that maps recipe keys to transform modules.

  Recipes persist keys, not module names, so this is the single place that
  resolves a key back to code. Adding a transform means adding its module and
  registering it in `@transforms`.
  """

  alias Revkit.Engine.Transforms.{Base64Encode, BashWrapper, UrlEncode}

  @transforms [Base64Encode, UrlEncode, BashWrapper]

  @doc "Returns every registered transform module."
  @spec all() :: [module()]
  def all, do: @transforms

  @doc "Finds a registered transform by atom or string key."
  @spec fetch(atom() | String.t()) :: module() | nil
  def fetch(key) when is_atom(key), do: Enum.find(@transforms, &(&1.key() == key))

  def fetch(key) when is_binary(key) do
    Enum.find(@transforms, &(Atom.to_string(&1.key()) == key))
  end

  @doc """
  Resolves stored recipe steps into `{module, options}` pairs for `Chain.run/2`.

  Steps have the shape `%{"key" => "base64_encode", "options" => %{}}`; atom
  keys are accepted too. Resolution halts at the first unknown key or malformed
  step.
  """
  @spec resolve([map()]) ::
          {:ok, [{module(), map()}]}
          | {:error, {:unknown_transform, term()} | {:invalid_step, term()}}
  def resolve(steps) when is_list(steps) do
    steps
    |> Enum.reduce_while({:ok, []}, fn step, {:ok, acc} ->
      key = step_key(step)
      options = step_options(step)

      cond do
        is_nil(key) or not is_map(options) ->
          {:halt, {:error, {:invalid_step, step}}}

        module = fetch(key) ->
          {:cont, {:ok, [{module, options} | acc]}}

        true ->
          {:halt, {:error, {:unknown_transform, key}}}
      end
    end)
    |> case do
      {:ok, resolved} -> {:ok, Enum.reverse(resolved)}
      error -> error
    end
  end

  defp step_key(%{"key" => key}) when is_binary(key) or is_atom(key), do: key
  defp step_key(%{key: key}) when is_binary(key) or is_atom(key), do: key
  defp step_key(_step), do: nil

  defp step_options(%{"options" => options}), do: options
  defp step_options(%{options: options}), do: options
  defp step_options(_step), do: %{}
end
