require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "register creates a user and logs them in" do
    assert_difference -> { User.count }, 1 do
      post register_path, params: { user: { email: "New@Example.com ", password: "password123",
                                             password_confirmation: "password123" } }
    end
    assert_equal "new@example.com", User.last.email
    assert_equal User.last.id, session[:user_id]
    assert_response :redirect
  end

  test "register rejects a mismatched confirmation" do
    assert_no_difference -> { User.count } do
      post register_path, params: { user: { email: "a@example.com", password: "password123",
                                             password_confirmation: "nope12345" } }
    end
    assert_response :unprocessable_entity
  end

  test "register rejects a taken email" do
    post register_path, params: { user: { email: users(:fresh).email, password: "password123",
                                           password_confirmation: "password123" } }
    assert_response :unprocessable_entity
  end

  test "login with the right password, then logout" do
    sign_in_as users(:fresh)
    assert_equal users(:fresh).id, session[:user_id]

    delete logout_path
    assert_nil session[:user_id]
    assert_redirected_to root_path
  end

  test "login with a wrong password fails" do
    sign_in_as users(:fresh), password: "wrong-password"
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
    assert_includes response.body, "Invalid email or password"
  end

  test "header shows login state" do
    get auctions_path
    assert_select ".profile__menu a", text: "Login"

    sign_in_as users(:fresh)
    get auctions_path
    assert_select ".profile__who", text: users(:fresh).email
    assert_select ".profile__menu button", text: "Logout"
  end
end
