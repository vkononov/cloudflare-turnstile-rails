class PagesController < ApplicationController
  def home; end

  def contact; end

  def submit_contact
    if valid_turnstile?
      redirect_to root_url, notice: 'Message sent successfully.'
    else
      redirect_to contact_url
    end
  end
end
