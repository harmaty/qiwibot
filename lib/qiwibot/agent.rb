require 'watir'
require 'nokogiri'
require 'headless'

module Qiwibot
  class Agent

    attr_accessor :browser, :logger

    SERVER_URL = 'https://qiwi.com'
    BROWSER = 'chrome'

    def initialize(login, password, sms_server = nil, sms_token = nil)
      @login, @password = login, password

      @logger = Logger.new 'log/qiwi_agent.log'
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{severity} [#{datetime.strftime('%Y-%m-%d %H:%M:%S.%6N')} ##{Process.pid}]:     #{msg[0, 300]}\n"
      end

      #sms_messages = SmsMessages.new sms_server, sms_token
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

    def send_money_by_chunks(amount:, receiver_phone:, text:, chunk_size: 15000)
      logger.info "[send_money_by_chunks: #{amount} #{receiver_phone} #{text}]"
      # Нужно уточнить если была выплата
      paid_amount = calculate_paid_amount(text)
      remaining_amount = amount - paid_amount
      if remaining_amount > 0
        n = (remaining_amount/chunk_size.to_f).floor
        remainder = remaining_amount%chunk_size.to_f
        n.times { send_money(chunk_size, receiver_phone, text) }
        send_money(remainder, receiver_phone, text) if remainder >= 1
      end
      sleep 5
      # Проверка что транзакция существует
      paid_amount = calculate_paid_amount(text)
      if (amount - paid_amount).abs >= 1
        raise PaymentError, "Failed to send all funds: unpaid amount: #{amount - paid_amount}"
      end
      logger.info "qiwi_balance=#{balance} amount=#{amount} balance_before=#{Currency.find_by_code('qiwi_rur').reserve} "
      transaction_ids(text).join(',')
    end

    def send_money(amount, receiver_phone, text)
      browser.goto SERVER_URL + '/transfer/form.action'
      browser.div(class: 'qiwi-payment-amount-control').wait_until_present
      browser.div(class: 'qiwi-payment-amount-control').text_field.value= amount
      browser.div(class: 'qiwi-payment-form-container').text_field.value= format_phone(receiver_phone)
      browser.div(class: 'qiwi-payment-form-comment').text_field.value= text
      sleep 5
      browser.div(class: 'qiwi-orange-button').click
      logger.info 'submitted the form'
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
      logger.info 'confirmed'
      if @sms_check_required
        time = Time.now
        begin
          browser.form(class: 'qiwi-confirmation-smsform').wait_until_present
        rescue Watir::Wait::TimeoutError => e
          if browser.div(class: 'resultPage').i(class: 'icon-error').exists?
            raise PaymentError, 'Invalid Payment'
          else
            raise e
          end
        end

        Watir::Wait.until(120, "Sms was not received") { codes_received_since(time).any? }
        sms_code = codes_received_since(time).last
        logger.info "sms_code = #{sms_code}"
        browser.form(class: 'qiwi-confirmation-smsform').text_field.value = sms_code
        browser.form(class: 'qiwi-confirmation-smsform').div(class: 'qiwi-orange-button').click
        logger.info 'received sms and submitted'
      end

      browser.div(class: 'payment-success').wait_until_present
      raise browser.div(id: 'content').text unless browser.div(data_widget: 'payment-success').present?
      logger.info 'payment success'
      true
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

    def calculate_paid_amount(text)
      @transaction_history = transaction_history
      @transaction_history.select { |t| t[:comment] =~ /^#{text}/ }.map { |t| t[:amount] }.sum.round(2)
    end

    def transaction_ids(text)
      @transaction_history ||= transaction_history
      @transaction_history.select { |t| t[:comment] =~ /^#{text}/ }.map { |t| t[:transaction_id] }
    end

    def codes_received_since(time, regexp = /Kod\:\s(\d+)/)
      sms_messages = SmsMessages.get(since: time)
      sms_messages.map(&:message).map { |m| m.scan(regexp).first }.compact
    end

  end

  class PaymentError < Exception
  end

end
