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

  def make_order(amount, sender_phone, text)
    browser.goto SERVER_URL + '/transfer/order.action'
    browser.text_field(name: 'to').wait_until_present
    browser.text_field(name: 'to').value= sender_phone
    browser.text_field(name: 'value').value= '%.02f' % amount
    browser.text_field(name: 'comment').value = text
    browser.execute_script("$('form.payment_frm select#currency-select').remove()")
    browser.execute_script("$('form.payment_frm').append('<input name=\"currency\" type=\"text\" value=\"RUB\">')")
    sleep 1
    browser.button(class: 'orangeBtn').click
    browser.div(class: 'resultPage').wait_until_present
    true
  end

  def transaction_history
    logger.info "[transaction_history]"
    browser.goto SERVER_URL + '/report/list.action?type=3'
    begin
      browser.div(data_widget: 'report-list').wait_until_present
    rescue => e
      if browser.div(data_widget: 'person-password-form').present?
        Rails.logger.debug "[qiwi_agent] password to be changed"
        change_password
        browser.goto SERVER_URL + '/report/list.action?type=3'
        browser.div(data_widget: 'report-list').wait_until_present
      end
    end
    transactions = []
    logger.info 'ready to parse transactions'
    return [] unless browser.div(class: 'reports').present?

    reports = browser.div(class: 'reports').html
    doc = Nokogiri::HTML(reports)
    doc.css(".reportsLine.status_SUCCESS").each do |report|
      transaction = {}
      transaction[:time] = report.css('.DateWithTransaction').css('.time').text.strip
      transaction[:date] = report.css('.DateWithTransaction').css('.date').text.strip
      transaction[:transaction_id] = report.css('.DateWithTransaction').css('.transaction').text.strip
      transaction[:comment] = report.css('.ProvWithComment').css('.comment').text.strip
      transaction[:transaction_type] = report.css('.income').any? ? 'input' : 'output'
      if transaction[:transaction_type] == 'input'
        transaction[:payer] = report.css('.ProvWithComment').css('.opNumber').text.strip
      else
        transaction[:payee] = report.css('.ProvWithComment').css('.opNumber').text.strip
      end
      transaction[:amount] = report.css('.cash').text.strip.gsub(' ', '').gsub(',', '.').to_f
      transactions << transaction
    end

    transactions
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
