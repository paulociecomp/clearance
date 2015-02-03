require "spec_helper"

describe Clearance::PasswordResetsController do
  it { is_expected.to be_a Clearance::BaseController }

  describe "#new" do
    it "renders the password reset form" do
      user = create(:user)

      get :new, user_id: user

      expect(response).to be_success
      expect(response).to render_template(:new)
    end
  end

  describe "#create" do
    context "email corresponds to an existing user" do
      it "creates a password reset for the user" do
        user = create(:user)

        post :create, password: { email: user.email.upcase }

        password_reset = PasswordReset.first
        expect(password_reset.user_id).to eq user.id
      end

      it "sends the password reset email" do
        ActionMailer::Base.deliveries.clear
        user = create(:user)

        post :create, password: { email: user.email }

        email = ActionMailer::Base.deliveries.last
        expect(email.subject).to match(/change your password/i)
      end
    end

    context "email does not belong to an existing user" do
      it "does not deliver an email" do
        ActionMailer::Base.deliveries.clear
        email = "this_user_does_not_exist@non_existent_domain.com"

        post :create, password: { email: email }

        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "still responds with success so as not to leak registered users" do
        email = "this_user_does_not_exist@non_existent_domain.com"

        post :create, password: { email: email }

        expect(response).to be_success
        expect(response).to render_template "passwords/create"
      end
    end
  end

  describe "#edit" do
    context "valid id and token are supplied" do
      it "renders the password form for the user" do
        password_reset = create(:password_reset)

        get :edit, user_id: password_reset.user_id, token: password_reset.token

        expect(response).to be_success
        expect(response).to render_template(:edit)
        expect(assigns(:password_reset)).to eq password_reset
      end
    end

    context "blank token is supplied" do
      it "renders the new password reset form with a flash notice" do
        get :edit, user_id: 1, token: ""

        expect(response).to render_template(:new)
        expect(flash.now[:notice]).to match(/double check the URL/i)
      end
    end

    context "invalid token is supplied" do
      it "renders the new password reset form with a flash notice" do
        password_reset = create(:password_reset)

        get :edit,
          user_id: password_reset.user,
          token: password_reset.token + "a"

        expect(response).to render_template(:new)
        expect(flash.now[:notice]).to match(/double check the URL/i)
      end
    end

    context "an expired token is supplied" do
      it "renders the new password reset form with a flash notice" do
        password_reset = create(:password_reset)
        password_reset.update(expires_at: 1.day.ago)

        get :edit,
          user_id: password_reset.user,
          token: password_reset.token

        expect(response).to render_template(:new)
        expect(flash.now[:notice]).to match(/double check the URL/i)
      end
    end
  end

  describe "#update" do
    context "valid id, token, and new password provided" do
      it "updates the user's password" do
        user = create(:user)
        password_reset = create(:password_reset, user: user)
        old_encrypted_password = user.encrypted_password

        put :update, update_parameters(password_reset, new_password: "my_new_password")

        expect(user.reload.encrypted_password).not_to eq old_encrypted_password
      end

      it "sets the remember token" do
        user = create(:user)
        password_reset = create(:password_reset, user: user)

        put :update, update_parameters(password_reset, new_password: "my_new_password")

        expect(user.remember_token).not_to be_nil
      end

      it "invalidates all other reset tokens" do
        user = create(:user)
        password_reset = create(:password_reset, user: user)
        invalidator = double(:invalidator)
        allow(Clearance::PasswordResetInvalidator).to receive(:new).and_return(invalidator)
        allow(invalidator).to receive(:run)

        put :update, update_password(password_reset, new_password: "new_password")

        expect(Clearance::PasswordResetInvalidator).to have_received(:new).with(user)
        expect(invalidator).to have_received(:run)
      end

      it "signs the user in and redirects" do
        user = create(:user)
        password_reset = create(:password_reset, user: user)

        put :update, update_parameters(password_reset, new_password: "my_new_password")

        expect(response).to redirect_to(Clearance.configuration.redirect_url)
        expect(cookies[:remember_token]).to be_present
      end
    end

    context "no password provided" do
      it "does not update the password" do
        user = create(:user, :with_forgotten_password)
        old_encrypted_password = user.encrypted_password

        put :update, update_parameters(password_reset, new_password: "")

        user.reload
        expect(user.encrypted_password).to eq old_encrypted_password
        expect(user.confirmation_token).to be_present
      end

      it "re-renders the password edit form" do
        user = create(:user, :with_forgotten_password)

        put :update, update_parameters(password_reset, new_password: "")

        expect(flash.now[:notice]).to match(/password can't be blank/i)
        expect(response).to render_template(:edit)
        expect(cookies[:remember_token]).to be_nil
      end
    end
  end

  def update_parameters(password_reset, options = {})
    new_password = options.fetch(:new_password)

    {
      user_id: password_reset.user_id,
      token: password_reset.token,
      password_reset: { password: new_password }
    }
  end
end
