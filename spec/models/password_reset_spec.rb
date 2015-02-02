require "spec_helper"

describe PasswordReset do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:user_id) }

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
        expect(Clearance.configuration).
          to have_received(:password_reset_time_limit)
        expect(password_reset.expires_at).not_to be_nil
      end
    end
  end
end
