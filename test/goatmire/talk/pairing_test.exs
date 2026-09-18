defmodule Goatmire.Talk.PairingTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias Goatmire.Talk.Pairing
  alias GoatmireWeb.Presenter.PairingCode

  setup do
    Pairing.revoke()
    on_exit(&Pairing.revoke/0)
  end

  test "a code opens exactly one session and announces it" do
    Phoenix.PubSub.subscribe(Goatmire.PubSub, Pairing.topic())
    {:ok, code} = Pairing.issue()

    assert Pairing.redeem(code) == :ok
    assert_receive :talk_paired
    assert Pairing.redeem(code) == :error
  end

  test "a new code replaces the previous one" do
    {:ok, first} = Pairing.issue()
    {:ok, second} = Pairing.issue()

    assert Pairing.redeem(first) == :error
    assert Pairing.redeem(second) == :ok
  end

  test "revoked and expired codes are refused" do
    {:ok, revoked} = Pairing.issue()
    :ok = Pairing.revoke()
    assert Pairing.redeem(revoked) == :error

    {:ok, expired} = Pairing.issue()
    :sys.replace_state(Pairing, &%{&1 | expires_at: &1.expires_at - Pairing.ttl_ms() - 1})
    assert Pairing.redeem(expired) == :error
  end

  test "no code is issued without a stage token" do
    original = Goatmire.Config.talk_remote_token()
    on_exit(fn -> Application.put_env(:goatmire, :talk_remote_token, original) end)
    Application.put_env(:goatmire, :talk_remote_token, nil)

    assert Pairing.issue() == {:error, :remote_disabled}
  end

  test "the QR code encodes a redeemable link on the stage host" do
    {:ok, %{qr: "data:image/svg+xml;base64," <> svg, url: url}} = PairingCode.start()

    assert Base.decode64!(svg) =~ "<svg"
    assert [_, code] = Regex.run(~r{^http://192\.0\.2\.1:\d+/talk/notes/pair/([\w-]+)$}, url)
    assert Pairing.redeem(code) == :ok
  end

  test "without a stage host the QR code explains that remote notes are off" do
    original = Goatmire.Config.talk_host()
    on_exit(fn -> Application.put_env(:goatmire, :talk_host, original) end)
    Application.put_env(:goatmire, :talk_host, nil)

    assert PairingCode.start() == {:error, :remote_disabled}
  end
end
