class Mailer < ActionMailer::Base
  layout 'mailer'

  def welcome_venue_manager(user)
    @user = user
    mail(
      to: @user.email, 
      subject: 'Welcome to LYTiT Venue Manager'
    )
  end

  def welcome_user(user)
    @user = user
    mail(
      to: @user.email, 
      subject: 'Welcome to LYTiT'
    )
  end

  def email_validation(user)
    @user = user
    mail(
      to: @user.email, 
      subject: 'Congratulations from Team LYTiT!'
    )
  end

  def notify_admins_of_monthly_winners(user)
    @user = user
    mail(
      to: @user.email, 
      subject: 'Monthly Lumen Game Winners Have Been Selected'
    )
  end

end
