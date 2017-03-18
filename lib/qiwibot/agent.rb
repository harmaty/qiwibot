require 'watir'
require 'nokogiri'
require 'headless'
require 'timeout'

module Qiwibot
  class Agent

    attr_accessor :browser, :logger

    SERVER_URL = 'https://qiwi.com'
    BROWSER = :chrome

    def initialize(login, password, sms_host = '0.0.0.0', sms_port = 8082)
      @login, @password = login, password

      @logger = Logger.new 'log/qiwi_agent.log'
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{severity} [#{datetime.strftime('%Y-%m-%d %H:%M:%S.%6N')} ##{Process.pid}]:     #{msg[0, 300]}\n"
      end

      @sms_check_required = true
      @sms_message = SmsMessage.new({pattern: /Kod\:\s(\d+)/, host: sms_host, port: sms_port})
    end

    def start
      open_browser
      login
    end

    def stop
      logout
      close_browser
    end

    def balance(options = {})
      logger.info "[balance]"
      visit_main_page
      account = browser.div(class: 'account_current_amount').text
      result = account.gsub(' ', '').sub(',', '.').to_f
      logger.info "  balance is #{result}"
      result
    end

    def make_order(amount:, sender_phone:, text:)
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

    def transaction_history(options = {})
      logger.info "[transaction_history]"
      browser.goto SERVER_URL + '/report/list.action?type=3'
      browser.div(data_widget: 'report-list').wait_until_present

      transactions = []
      logger.info '  ready to parse transactions'
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

    def send_money(amount:, receiver_phone:, text:, chunk_size: 15000)
      amount = amount.to_f
      chunk_size = chunk_size.to_f

      logger.info "[send_money: #{amount} #{receiver_phone} #{text}]"
      # Нужно уточнить если была выплата
      paid_amount = calculate_paid_amount(text)
      remaining_amount = amount - paid_amount
      if remaining_amount > 0
        n = (remaining_amount/chunk_size).floor
        remainder = remaining_amount%chunk_size
        n.times { send_money(chunk_size, receiver_phone, text) }
        send_money_once(remainder, receiver_phone, text) if remainder >= 1
      end
      sleep 3
      # Проверка что транзакция существует
      paid_amount = calculate_paid_amount(text)
      if (amount - paid_amount).abs >= 1.0
        raise PaymentError, "Failed to send all funds: unpaid amount: #{amount - paid_amount}"
      end
      logger.info "  payment (#{amount} #{receiver_phone} #{text}) completed"
      transaction_ids(text).join(',')
    end

    def send_money_once(amount, receiver_phone, text)
      browser.goto SERVER_URL + '/transfer/form.action'

      browser.div(class: 'qiwi-payment-amount-control').wait_until_present
      browser.div(class: 'qiwi-payment-amount-control').text_field.value= amount
      receiver_phone.split('').each do |num|
        browser.execute_script("keyVal=48 + #{num};$('.qiwi-payment-form-container input').trigger({ type: 'keypress', keyCode: keyVal, which: keyVal, charCode: keyVal });")
      end
      #browser.div(class: 'qiwi-payment-form-container').text_field.value= format_phone(receiver_phone)
      browser.div(class: 'qiwi-payment-form-comment').text_field.value= text

      sleep 2
      browser.div(class: 'qiwi-orange-button').click
      logger.info '  submitted the payment form'
      begin
        browser.div(class: 'qiwi-payment-confirm').wait_until_present
      rescue Watir::Wait::TimeoutError => e
        if browser.span(class: 'errorElement').exists?
          puts 'Error in form, stopped'
          raise PaymentError, "Error in form: #{browser.span(class: 'errorElement').text}"
        else
          raise e
        end
      end
      browser.div(class: 'qiwi-payment-confirm').div(class: 'qiwi-orange-button').click
      logger.info '  payment confirmed'
      if @sms_check_required
        begin
          browser.form(class: 'qiwi-confirmation-smsform').wait_until_present
        rescue Watir::Wait::TimeoutError => e
          if browser.div(class: 'resultPage').i(class: 'icon-error').exists?
            raise PaymentError, 'Invalid Payment'
          else
            raise e
          end
        end

        sms_code = ''
        puts 'Please enter sms code:'

        Timeout::timeout(60) { sms_code = @sms_message.receive }

        logger.info "  sms_code = #{sms_code}"
        puts "Kod is #{sms_code}"

        browser.form(class: 'qiwi-confirmation-smsform').text_field.value = sms_code
        browser.form(class: 'qiwi-confirmation-smsform').div(class: 'qiwi-orange-button').click
        logger.info '  received sms and submitted'
      end

      browser.div(class: 'payment-success').wait_until_present
      raise browser.div(id: 'content').text unless browser.div(data_widget: 'payment-success').present?
      logger.info '  payment success'
      true
    end

    def logged_in?
      browser.exists? &&
          browser.div(class: 'phone').exists? &&
          browser.div(class: 'phone').text.include?(@login)
    end

    def login
      logger.info '[logging in]'
      browser.goto SERVER_URL
      browser.div(class: 'header-login-item-login').click
      browser.div(class: 'phone-input-container').text_field.value = @login
      browser.text_field(class: 'qw-auth-form-password-remind-input').value = @password
      browser.button(class: 'qw-submit-button').click
      browser.div(class: 'phone').wait_until_present
      logger.info '  logged in'
      true
    end

    def logout
      #TODO implement it
    end

    def alive?
      browser.exists?
    end

    private

    def open_browser
      if RUBY_PLATFORM =~ /linux/i
        @headless = Headless.new
        @headless.start
        driver = Selenium::WebDriver.for BROWSER
        @browser = Watir::Browser.new driver
      else
        @browser = Watir::Browser.new BROWSER
      end
    end

    def visit_main_page
      browser.goto SERVER_URL + '/main.action'
    end

    def close_browser
      browser.close
    end

    def calculate_paid_amount(text)
      @transaction_history = transaction_history
      @transaction_history.select { |t| t[:comment] =~ /^#{text}/ }.inject(0) { |sum, t| sum += t[:amount] }.round(2)
    end

    def transaction_ids(text)
      @transaction_history ||= transaction_history
      @transaction_history.select { |t| t[:comment] =~ /^#{text}/ }.map { |t| t[:transaction_id] }
    end

  end

  class PaymentError < Exception
  end

end
