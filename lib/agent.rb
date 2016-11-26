require 'watir'

class Agent

  attr_accessor :browser, :logger

  SERVER_URL = 'https://qiwi.com'

  def initialize(login, password)
    @login, @password = login, password

    @logger = Logger.new 'log/qiwi_agent.log'
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{severity} [#{datetime.strftime('%Y-%m-%d %H:%M:%S.%6N')} ##{Process.pid}]:     #{msg[0, 300]}\n"
    end
  end

  def start
    open_browser
    login
  end

  def stop
    logout
    close_browser
  end

  def balance
    visit_main_page
    account = browser.div(class: 'account_current_amount').text
    account.gsub(' ', '').sub(',', '.').to_f
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

  def visit_main_page
    browser.goto SERVER_URL + '/main.action'
  end

  def login
    logger.info 'logging in'
    browser.goto SERVER_URL
    browser.div(class: 'header-login-item-login').click
    browser.div(class: 'phone-input-container').text_field.value = @login
    browser.text_field(class: 'qw-auth-form-password-remind-input').value = @password
    browser.button(class: 'qw-submit-button').click
    puts 'Logged in'
    true
  end

  def logout

  end

  def close_browser
    browser.close
  end

end
