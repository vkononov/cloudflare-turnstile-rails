class ContactsController < ApplicationController
  def new; end

  def create
    if valid_turnstile?
      redirect_to root_url, notice: 'Message sent successfully.'
    else
      redirect_to new_contact_url
    end
  end
end
