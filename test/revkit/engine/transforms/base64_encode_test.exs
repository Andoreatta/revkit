defmodule Revkit.Engine.Transforms.Base64EncodeTest do
  use ExUnit.Case, async: true

  alias Revkit.Engine.Transforms.Base64Encode

  describe "apply/2" do
    test "encodes ASCII" do
      assert Base64Encode.apply("hello", %{}) == {:ok, "aGVsbG8="}
    end

    test "encodes an empty payload" do
      assert Base64Encode.apply("", %{}) == {:ok, ""}
    end

    test "encodes UTF-8 bytes" do
      assert Base64Encode.apply("héllo", %{}) == {:ok, "aMOpbGxv"}
    end

    test "preserves multiline payloads" do
      assert Base64Encode.apply("echo one\necho two", %{}) ==
               {:ok, "ZWNobyBvbmUKZWNobyB0d28="}
    end

    test "round-trips through Base64 decoding" do
      payload = "echo 'héllo'\n"
      assert {:ok, encoded} = Base64Encode.apply(payload, %{})
      assert Base.decode64!(encoded) == payload
    end

    test "ignores options" do
      assert Base64Encode.apply("hello", %{unused: true}) == Base64Encode.apply("hello", %{})
    end
  end

  describe "metadata" do
    test "exposes the encoding contract" do
      assert Base64Encode.key() == :base64_encode
      assert Base64Encode.label() == "Base64 encode"
      assert Base64Encode.kind() == :encoding
      assert Base64Encode.requires() == []
      assert is_list(Base64Encode.pitfalls())
    end
  end
end
