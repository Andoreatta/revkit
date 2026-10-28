defmodule RevkitWeb.StepEditor do
  @moduledoc """
  Shared ordered transform editor for the generator and recipe form.

  The UI component and the pure list helpers live together so both LiveViews
  use one representation: `%{id: integer, key: string, options: map}`.
  """

  use RevkitWeb, :html

  alias Revkit.Engine.Transforms

  attr :steps, :list, required: true
  attr :name_prefix, :string, required: true
  attr :id_prefix, :string, required: true
  attr :errors, :list, default: []

  def step_editor(assigns) do
    ~H"""
    <div class="space-y-2">
      <div class="flex items-center justify-between">
        <h3 class="text-sm font-semibold">Transform chain</h3>
        <button
          type="button"
          id={"#{@id_prefix}-add-step"}
          class="btn btn-ghost btn-sm"
          phx-click="add_step"
        >
          <.icon name="hero-plus" class="size-4" /> Add transform
        </button>
      </div>

      <p :if={@steps == []} class="text-sm text-base-content/60">
        No transforms yet. The payload passes through unchanged.
      </p>

      <div
        :for={{step, index} <- Enum.with_index(@steps)}
        id={"#{@id_prefix}-step-#{index}"}
        class="flex flex-col gap-2 rounded-box bg-base-200 p-3 sm:flex-row sm:items-center"
      >
        <select name={"#{@name_prefix}[#{index}][key]"} class="w-full select select-sm sm:flex-1">
          <option value="">Select a transform</option>
          <option
            :if={step.key != "" and is_nil(Transforms.fetch(step.key))}
            value={step.key}
            selected
          >
            {step.key} (unknown)
          </option>
          <option
            :for={transform <- Transforms.all()}
            value={transform.key()}
            selected={step.key == Atom.to_string(transform.key())}
          >
            {transform.label()}
          </option>
        </select>

        <div class="flex gap-1">
          <button
            type="button"
            class="btn btn-ghost btn-xs"
            phx-click="move_step"
            phx-value-id={step.id}
            phx-value-direction="up"
            aria-label="Move up"
          >
            <.icon name="hero-arrow-up" class="size-4" />
          </button>
          <button
            type="button"
            class="btn btn-ghost btn-xs"
            phx-click="move_step"
            phx-value-id={step.id}
            phx-value-direction="down"
            aria-label="Move down"
          >
            <.icon name="hero-arrow-down" class="size-4" />
          </button>
          <button
            type="button"
            class="btn btn-ghost btn-xs text-error"
            phx-click="remove_step"
            phx-value-id={step.id}
            aria-label="Remove step"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
      </div>

      <p :for={error <- @errors} class="text-sm text-error">
        {translate_error(error)}
      </p>
    </div>
    """
  end

  @doc "Converts persisted recipe steps into editor steps."
  def to_editor_steps(steps) when is_list(steps) do
    Enum.map(steps, fn step ->
      %{
        id: System.unique_integer([:positive]),
        key: step["key"] || step[:key] || "",
        options: step["options"] || step[:options] || %{}
      }
    end)
  end

  def to_editor_steps(_steps), do: []

  @doc "Returns a new blank editor step."
  def new_step, do: %{id: System.unique_integer([:positive]), key: "", options: %{}}

  @doc "Appends a blank editor step."
  def add(steps), do: steps ++ [new_step()]

  @doc "Removes an editor step by id."
  def remove(steps, id) do
    id = to_integer(id)
    Enum.reject(steps, &(&1.id == id))
  end

  @doc "Moves an editor step up or down."
  def move(steps, id, direction) do
    id = to_integer(id)
    index = Enum.find_index(steps, &(&1.id == id))

    cond do
      is_nil(index) -> steps
      direction == "up" and index > 0 -> swap(steps, index, index - 1)
      direction == "down" and index < length(steps) - 1 -> swap(steps, index, index + 1)
      true -> steps
    end
  end

  @doc "Merges submitted step keys into the current editor steps."
  def merge(steps, step_params) when is_map(step_params) do
    steps
    |> Enum.with_index()
    |> Enum.map(fn {step, index} ->
      case Map.get(step_params, Integer.to_string(index)) do
        nil -> step
        params -> %{step | key: params["key"] || ""}
      end
    end)
  end

  def merge(steps, _step_params), do: steps

  @doc "Serializes editor steps for the Recipe changeset."
  def to_attrs(steps) do
    Enum.map(steps, fn step ->
      %{"key" => step.key || "", "options" => step.options || %{}}
    end)
  end

  defp swap(steps, left, right) do
    steps
    |> List.replace_at(left, Enum.at(steps, right))
    |> List.replace_at(right, Enum.at(steps, left))
  end

  defp to_integer(id) when is_integer(id), do: id
  defp to_integer(id), do: String.to_integer(id)
end
