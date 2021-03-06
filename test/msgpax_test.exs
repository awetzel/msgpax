defmodule MsgpaxTest do
  use ExUnit.Case, async: true

  defp string(len),
    do: String.duplicate(".", len)

  defp list(len),
    do: List.duplicate(nil, len)
  
  defp bytes(len),
    do: String.duplicate(<<200>>, len)

  defp proplist(0), do: [{}]
  defp proplist(len) do
    Stream.iterate({0, true}, fn {n, v} -> {n + 1, v} end)
    |> Enum.take(len)
  end

  defp map(0), do: %{}
  defp map(len) do
    proplist(len)
    |> Enum.into(%{})
  end

  defmacrop assert_format(term, format, result \\ nil) do
    quote location: :keep do
      assert {:ok, packed} = Msgpax.pack(unquote(term))
      assert <<unquote_splicing(format), _::bytes>> = IO.iodata_to_binary(packed)
      assert {:ok, unpacked} = Msgpax.unpack(packed)
      assert unpacked == unquote(result || term)
    end
  end

  defmacrop assert_error(expr, reason) do
    quote do
      assert Msgpax.unquote(expr) == {:error, unquote(reason)}
    end
  end

  test "fixstring" do
    assert_format string(0), [160]
    assert_format string(31), [191]
  end

  test "string 8" do
    assert_format string(32), [217, 32]
    assert_format string(255), [217, 255]
  end

  test "string 16" do
    assert_format string(256), [218, 1, 0]
    assert_format string(65535), [218, 255, 255]
  end

  test "string 32" do
    assert_format string(65536), [219, 0, 1, 0, 0]
  end

  test "binary 8" do
    assert_format bytes(1), [0xC4, 1]
    assert_format bytes(0xFF), [0xC4, 0xFF::8]
  end

  test "binary 16" do
    assert_format bytes(0x100), [0xC5, 0x100::16]
    assert_format bytes(0xFFFF), [0xC5, 0xFFFF::16]
  end

  test "binary 32" do
    assert_format bytes(0x10000), [0xC6, 0x10000::32]
  end

  test "fixarray" do
    assert_format list(0), [144]
    assert_format list(15), [159]
  end

  test "array 16" do
    assert_format list(16), [220, 0, 16]
    assert_format list(65535), [220, 255, 255]
  end

  test "array 32" do
    assert_format list(65536), [221, 0, 1, 0, 0]
  end

  test "fixmap" do
    assert_format map(0), [128]
    assert_format map(15), [143]

    assert_format proplist(0), [128], map(0)
    assert_format proplist(15), [143], map(15)
  end

  test "map 16" do
    assert_format map(16), [222, 0, 16]
    assert_format map(65535), [222, 255, 255]
  end

  test "map 32" do
    assert_format map(65536), [223, 0, 1, 0, 0]
  end

  test "booleans" do
    assert_format false, [194]
    assert_format true, [195]
  end

  test "nil" do
    assert_format nil, [192]
  end

  test "atoms" do
    assert_format :ok, [162], "ok"
    assert_format Atom, [171], "Elixir.Atom"
  end

  test "float" do
    assert_format 42.1, [203]
  end

  test "positive fixint" do
    assert_format 0, [0]
    assert_format 127, [127]
  end

  test "uint 8" do
    assert_format 128, [204]
    assert_format 255, [204]
  end

  test "uint 16" do
    assert_format 256, [205]
    assert_format 65535, [205]
  end

  test "uint 32" do
    assert_format 65536, [206]
    assert_format 4294967295, [206]
  end

  test "uint 64" do
    assert_format 4294967296, [207]
  end

  test "negative fixint" do
    assert_format -1, [255]
    assert_format -32, [224]
  end

  test "int 8" do
    assert_format -33, [208]
    assert_format -128, [208]
  end

  test "int 16" do
    assert_format -129, [209]
    assert_format -32768, [209]
  end

  test "int 32" do
    assert_format -32769, [210]
    assert_format -2147483648, [210]
  end

  test "int 64" do
    assert_format -2147483649, [211]
  end

  test "bitstring" do
    assert_error pack([42, <<5::3>>]), {:badarg, <<5::3>>}
  end

  test "too big error" do
    assert_error pack([true, -9223372036854775809]), {:too_big, -9223372036854775809}
  end

  test "extra bytes error" do
    assert_error unpack(<<255, 1, 2>>), {:extra_bytes, <<1, 2>>}
  end

  test "extra bytes error-" do
    assert_error unpack(<<193, 1>>), {:invalid_format, 193}
  end

  test "incomplete binary" do
    assert_error unpack(<<147, 1, 2>>), :incomplete
  end
end
