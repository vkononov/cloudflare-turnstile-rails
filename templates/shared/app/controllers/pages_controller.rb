class PagesController < ApplicationController
  def home; end

  def lazy_demo
    head :ok if request.post?
  end

  def modal_demo
    head :ok if request.post?
  end
end
