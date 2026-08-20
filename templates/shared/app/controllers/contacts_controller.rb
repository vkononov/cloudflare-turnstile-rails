class ContactsController < ApplicationController
  def new; end

  def create
    if valid_turnstile?
      redirect_to root_url, notice: 'Message sent successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end
end
