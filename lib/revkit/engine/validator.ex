defmodule Revkit.Engine.Validator do
  @moduledoc """
  Aggregates transform requirements and pitfalls into a report.

  This is intentionally metadata-only: `requires/0` and `pitfalls/0` are
  advisory strings, and validation never inspects or executes the payload.
  """

  @typedoc "A target prerequisite, with the transforms that require it."
  @type requirement :: %{name: String.t(), transforms: [module()]}

  @typedoc "A transform warning, with the transforms that raised it."
  @type pitfall :: %{message: String.t(), transforms: [module()]}

  @type report :: %{requires: [requirement()], pitfalls: [pitfall()]}

  @doc """
  Builds a report from a resolved transform chain (`[{module, options}]`).

  Entries are de-duplicated in first-seen order. Source modules are also
  de-duplicated, so applying the same transform twice does not duplicate its
  warning sources.
  """
  @spec validate([{module(), map()}]) :: report()
  def validate(chain) when is_list(chain) do
    %{
      requires: collect(chain, :requires, :name),
      pitfalls: collect(chain, :pitfalls, :message)
    }
  end

  defp collect(chain, callback, key) do
    {order, sources} =
      Enum.reduce(chain, {[], %{}}, fn {module, _options}, acc ->
        module
        |> apply(callback, [])
        |> List.wrap()
        |> Enum.reduce(acc, fn entry, {order, sources} ->
          if Map.has_key?(sources, entry) do
            {order, Map.update!(sources, entry, &[module | &1])}
          else
            {[entry | order], Map.put(sources, entry, [module])}
          end
        end)
      end)

    order
    |> Enum.reverse()
    |> Enum.map(fn entry ->
      transforms =
        sources
        |> Map.fetch!(entry)
        |> Enum.reverse()
        |> Enum.uniq()

      %{key => entry, transforms: transforms}
    end)
  end
end
