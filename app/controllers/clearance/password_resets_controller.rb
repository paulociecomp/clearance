require 'active_support/deprecation'

class Clearance::PasswordResetsController < Clearance::BaseController
  skip_before_filter :require_login, only: [:create, :edit, :new, :update]
  skip_before_filter :authorize, only: [:create, :edit, :new, :update]
  before_filter :forbid_missing_token, only: [:edit, :update]
  before_filter :forbid_non_existent_user, only: [:edit, :update]

  def create
    if user = find_user_for_create
      password_reset = PasswordReset.create(user: user)
      deliver_email(user, password_reset)
    end
    render template: 'passwords/create'
  end

  def edit
    @user = find_user_for_edit
    render template: 'passwords/edit'
  end

  def new
    render template: 'passwords/new'
  end

  def update
    @user = find_user_for_update

    if @user.update_password password_reset_params
      sign_in @user
      redirect_to url_after_update
    else
      flash_failure_after_update
      render template: 'passwords/edit'
    end
  end

  private

  def deliver_email(user, password_reset)
    mail = ::ClearanceMailer.change_password(user, password_reset)

    if Gem::Version.new(Rails::VERSION::STRING) >= Gem::Version.new("4.2.0")
      mail.deliver_later
    else
      mail.deliver
    end
  end

  def password_reset_params
    if params.has_key? :user
      ActiveSupport::Deprecation.warn %{Since locales functionality was added, accessing params[:user] is no longer supported.}
      params[:user][:password]
    else
      params[:password_reset][:password]
    end
  end

  def find_user_by_id_and_confirmation_token
    if matching_password_reset = find_password_reset_by_user_id_and_token
      matching_password_reset.user
    end
  end

  def find_password_reset_by_user_id_and_token
    PasswordReset.find_by_user_id_and_token(
      params[user_param],
      params[:token].to_s,
    )
  end

  def user_param
    Clearance.configuration.user_id_parameter
  end

  def find_user_for_create
    Clearance.configuration.user_model.
      find_by_normalized_email params[:password][:email]
  end

  def find_user_for_edit
    find_user_by_id_and_confirmation_token
  end

  def find_user_for_update
    find_user_by_id_and_confirmation_token
  end

  def flash_failure_when_forbidden
    flash.now[:notice] = translate(:forbidden,
      scope: [:clearance, :controllers, :passwords],
      default: t('flashes.failure_when_forbidden'))
  end

  def flash_failure_after_update
    flash.now[:notice] = translate(:blank_password,
      scope: [:clearance, :controllers, :passwords],
      default: t('flashes.failure_after_update'))
  end

  def forbid_missing_token
    if params[:token].to_s.blank?
      flash_failure_when_forbidden
      render template: 'passwords/new'
    end
  end

  def forbid_non_existent_user
    unless find_user_by_id_and_confirmation_token
      flash_failure_when_forbidden
      render template: 'passwords/new'
    end
  end

  def url_after_create
    sign_in_url
  end

  def url_after_update
    Clearance.configuration.redirect_url
  end
end
