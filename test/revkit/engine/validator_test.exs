defmodule Revkit.Engine.ValidatorTest do
  use ExUnit.Case, async: true

  alias Revkit.Engine.Transforms.{Base64Encode, BashWrapper}
  alias Revkit.Engine.Validator

  test "returns an empty report for an empty chain" do
    assert Validator.validate([]) == %{requires: [], pitfalls: []}
  end

  test "collects requirements with their source transforms" do
    report = Validator.validate([{BashWrapper, %{}}])

    assert report.requires == [%{name: "bash", transforms: [BashWrapper]}]
    assert length(report.pitfalls) == 3
    assert Enum.all?(report.pitfalls, &(&1.transforms == [BashWrapper]))
  end

  test "collects pitfalls with their source transforms" do
    report = Validator.validate([{Base64Encode, %{}}])

    assert report.requires == []

    assert Enum.any?(report.pitfalls, fn pitfall ->
             pitfall.message =~ "Base64 is an encoding" and
               pitfall.transforms == [Base64Encode]
           end)
  end

  test "deduplicates entries and sources while preserving first-seen order" do
    report =
      Validator.validate([
        {BashWrapper, %{}},
        {Base64Encode, %{}},
        {BashWrapper, %{}}
      ])

    assert report.requires == [%{name: "bash", transforms: [BashWrapper]}]

    messages = Enum.map(report.pitfalls, & &1.message)
    assert length(messages) == length(Enum.uniq(messages))
    assert hd(messages) =~ "Requires bash"
    assert Enum.at(messages, 3) =~ "Base64 is an encoding"

    for pitfall <- report.pitfalls do
      assert pitfall.transforms == Enum.uniq(pitfall.transforms)
    end
  end

  test "ignores step options" do
    assert Validator.validate([{BashWrapper, %{"ignored" => true}}]) ==
             Validator.validate([{BashWrapper, %{}}])
  end
end
