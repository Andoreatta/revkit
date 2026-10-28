defmodule Revkit.Engine.Transforms.UrlEncodeTest do
  use ExUnit.Case, async: true

  alias Revkit.Engine.Transforms.UrlEncode

  describe "apply/2" do
    test "encodes spaces as %20" do
      assert UrlEncode.apply("echo hi", %{}) == {:ok, "echo%20hi"}
    end

    test "encodes reserved characters" do
      assert UrlEncode.apply("a+b/c=d", %{}) == {:ok, "a%2Bb%2Fc%3Dd"}
    end

    test "leaves unreserved characters untouched" do
      assert UrlEncode.apply("aZ0-._~", %{}) == {:ok, "aZ0-._~"}
    end

    test "encodes UTF-8 bytes" do
      assert UrlEncode.apply("é", %{}) == {:ok, "%C3%A9"}
    end

    test "encodes an empty payload" do
      assert UrlEncode.apply("", %{}) == {:ok, ""}
    end

    test "round-trips through URI decoding" do
      payload = "echo 'héllo' | bash"
      assert {:ok, encoded} = UrlEncode.apply(payload, %{})
      assert URI.decode(encoded) == payload
    end

    test "ignores options" do
      assert UrlEncode.apply("echo hi", %{unused: true}) == UrlEncode.apply("echo hi", %{})
    end
  end

  describe "metadata" do
    test "exposes the encoding contract" do
      assert UrlEncode.key() == :url_encode
      assert UrlEncode.label() == "URL encode"
      assert UrlEncode.kind() == :encoding
      assert UrlEncode.requires() == []
      assert is_list(UrlEncode.pitfalls())
    end
  end
end
