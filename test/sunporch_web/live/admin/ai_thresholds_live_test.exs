defmodule SunporchWeb.Admin.AIThresholdsLiveTest do
  use SunporchWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "non-admin" do
    setup %{conn: conn} do
      register_and_log_in_user(%{conn: conn})
    end

    test "redirects non-admin users", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/feed"}}} = live(conn, ~p"/admin/ai-thresholds")
    end
  end

  describe "admin" do
    setup %{conn: conn} do
      register_and_log_in_admin(%{conn: conn})
    end

    test "renders thresholds page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/ai-thresholds")
      assert html =~ "AI Detection Thresholds"
      assert html =~ "Text Detection"
      assert html =~ "Image Detection"
      assert html =~ "Soft Reject"
      assert html =~ "Hard Reject"
      assert html =~ "Save Thresholds"
    end

    test "can update thresholds", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/ai-thresholds")

      view
      |> form("form[phx-submit='update_thresholds']", %{
        text_soft_reject: "0.70",
        text_hard_reject: "0.90",
        image_soft_reject: "0.75",
        image_hard_reject: "0.95"
      })
      |> render_submit()

      # Verify thresholds are reflected in the page
      html = render(view)
      assert html =~ "0.7"
      assert html =~ "0.9"
    end
  end
end
