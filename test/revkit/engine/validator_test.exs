defmodule Revkit.Engine.ValidatorTest do
  use ExUnit.Case, async: true

  alias Revkit.Engine.Transforms.{Base64Encode, BashWrapper}
  alias Revkit.Engine.Validator

  test "returns an empty report for an empty chain" do
    assert Validator.validate([]) == %{
             requires: [],
             pitfalls: [],
             warnings: [],
             compatible: true
           }
  end

  test "accepts matching target capabilities" do
    report = Validator.validate([{BashWrapper, %{}}], %{os: "linux", shell: "bash"})

    assert report.compatible == true
    assert report.warnings == []
  end

  test "warns when the target metadata is missing" do
    report = Validator.validate([{BashWrapper, %{}}])

    assert report.compatible == false
    assert [%{type: :unknown_target}] = report.warnings
  end

  test "warns when a requirement is not declared by the target" do
    report = Validator.validate([{BashWrapper, %{}}], %{os: "linux", shell: "sh"})

    assert report.compatible == false
    assert [%{type: :missing_requirement, message: message}] = report.warnings
    assert message =~ "bash"
  end

  test "accepts a requirement declared as a target tool" do
    report = Validator.validate([{BashWrapper, %{}}], %{tools: ["bash"]})

    assert report.compatible == true
    assert report.warnings == []
  end

  test "normalizes target paths, case, and executable suffixes" do
    assert Validator.validate([{BashWrapper, %{}}], %{shell: "/bin/BASH"}).compatible
    assert Validator.validate([{BashWrapper, %{}}], %{tools: ["C:\\tools\\bash.exe"]}).compatible
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
