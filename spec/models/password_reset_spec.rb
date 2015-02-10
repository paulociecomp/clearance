require "spec_helper"

describe PasswordReset do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:user_id) }
  it { is_expected.to delegate_method(:user_email).to(:user).as(:email) }

  context "before create" do
    describe "#generate_token" do
      it "generates the token" do
        allow(Clearance::Token).to receive(:new).and_return("abc")

        password_reset = build(:password_reset)
        expect(password_reset.token).to be_nil

        password_reset.save
        expect(password_reset.token).to eq "abc"
      end
    end

    describe "#generate_expires_at" do
      it "generates an expiration timestamp for the reset" do
        allow(Clearance.configuration).to receive(:password_reset_time_limit).
          and_return(10.minutes)

        password_reset = build(:password_reset)
        expect(password_reset.expires_at).to be_nil

        password_reset.save
        expect(password_reset.expires_at).not_to be_nil
      end
    end
  end

  describe ".active_for" do
    it "returns all the unexpired password resets for a user" do
      user = create(:user)
      another_user = create(:user)
      password_reset = create(:password_reset, user: user)
      expired_password_reset = create(:password_reset, user: user)
      expired_password_reset.update_attributes(expires_at: 1.day.ago)
      _another_user_password_reset = create(:password_reset, user: another_user)

      expect(PasswordReset.active_for(user)).to match_array [password_reset]
    end
  end

  describe "#deactivate!" do
    it "sets the password resets expiration to now" do
      password_reset = create(:password_reset)

      password_reset.deactivate!

      expect(password_reset.reload).to be_expired
    end
  end

  describe ".time_limit" do
    it "returns the time limit as set in the Clearance configuration" do
      allow(Clearance.configuration).to receive(:password_reset_time_limit).
        and_return(10.minutes)

      expect(PasswordReset.time_limit).to eq 10.minutes
    end
  end

  describe "#expired?" do
    it "returns true if the reset has expired" do
      password_reset = create(:password_reset)
      password_reset.update_attributes(expires_at: 10.minutes.ago)

      expect(password_reset).to be_expired
    end

    it "returns false if the reset has not expired" do
      password_reset = create(:password_reset)
      password_reset.update_attributes(expires_at: 15.minutes.from_now)

      expect(password_reset).not_to be_expired
    end
  end
end
