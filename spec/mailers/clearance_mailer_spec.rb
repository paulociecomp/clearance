require "spec_helper"

describe ClearanceMailer do
  it "is from DO_NOT_REPLY" do
    password_reset = create(:password_reset)

    email = ClearanceMailer.change_password(password_reset)

    expect(Clearance.configuration.mailer_sender).to eq(email.from[0])
  end

  it "is sent to user" do
    password_reset = create(:password_reset)

    email = ClearanceMailer.change_password(password_reset)

    expect(email.to.first).to eq(password_reset.user_email)
  end

  it "contains a link to edit the password" do
    password_reset = create(:password_reset)

    host = ActionMailer::Base.default_url_options[:host]
    link = "http://#{host}/users/#{password_reset.user_id}/password/edit" \
      "?token=#{password_reset.token}"

    email = ClearanceMailer.change_password(password_reset)

    expect(email.body).to include(link)
  end

  it "sets its subject" do
    password_reset = create(:password_reset)

    email = ClearanceMailer.change_password(password_reset)

    expect(email.subject).to include("Change your password")
  end

  it "contains opening text in the body" do
    password_reset = create(:password_reset)
    allow(Clearance.configuration).to receive(:password_reset_time_limit).
      and_return(10.minutes)

    email = ClearanceMailer.change_password(password_reset)

    expect(email.body).to include(
      I18n.t(
        "clearance_mailer.change_password.opening",
        time_limit: "10 minutes"
      )
    )
  end

  it "contains closing text in the body" do
    password_reset = create(:password_reset)

    email = ClearanceMailer.change_password(password_reset)

    expect(email.body.raw_source).to include(
      I18n.t("clearance_mailer.change_password.closing")
    )
  end
end
