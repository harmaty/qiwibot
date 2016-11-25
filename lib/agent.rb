require 'watir'

class Agent

  attr_accessor :browser

  SERVER_URL = 'https://qiwi.com'

  def initialize(login, password)
    @login, @password = login, password
  end

  def start
    open_browser
    login
  end

  def balance
    1.0
  end

  def make_order

  end

  def transaction_history

  end

  def send_money_by_chunks
  end

  private

  def open_browser
    @browser = Watir::Browser.new :chrome
  end

  def login
    browser.goto SERVER_URL
    true
  end

end