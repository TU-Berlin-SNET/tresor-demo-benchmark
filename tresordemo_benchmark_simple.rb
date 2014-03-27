require 'slop'
require 'capybara'
require 'capybara/dsl'
require 'selenium/webdriver'
require 'faker'
require 'benchmark'
require 'mechanize'

I18n.enforce_available_locales = false

opts = Slop.parse do
  banner 'Usage: benchmark.rb [options]'

  on 'h=', 'host', 'The host to connect to'
  on 'p=', 'port', 'The port to connect to (default: 80)'
  on 'H=', 'proxy_host', 'HTTP proxy host'
  on 'P=', 'proxy_port', 'HTTP proxy port'
end

class TresordemoBenchmarkSimple
  #@return [Mechanize]
  attr_reader :agent

  def initialize(agent, host, port)
    @agent = agent
    @host = host
    @port = port
    @first_time = true
  end

  def do(bm)
    if @first_time
      total = bm.report ('Visit Home') { @agent.get("http://#{@host}:#{@port}/?locale=en") }
    else
      total = bm.report ('Visit Home') { @agent.get("/") }
    end

    total += bm.report ('Visit Login') { @agent.page.link_with(:text => 'Log in').click }

    @agent.page.form do |form|
      form['user[username]'] = 'arzt'
      form['user[password]'] = '1234'
    end

    total += bm.report ('Log in') { @agent.page.form.submit }

    5.times do
      total += create_new_patient(bm)
    end

    total += bm.report ('Sign out') do @agent.delete("/users/sign_out?locale=en") end

    total
  end

  def create_new_patient(bm)
    # First click on the menu to get to the patients
    total = bm.report ('List Patients') { @agent.page.link_with(:href => '/patients?locale=en').click }

    # Create new patient
    total += bm.report ('New Patient') { @agent.page.link_with(:text => 'New patient').click }

    # Fill in patient data
    @agent.page.form do |form|
      form['patient[first_name]'] = Faker::Name.first_name
      form['patient[last_name]'] = Faker::Name.last_name
      form['patient[sex]'] = ['male', 'female'][rand(2)]
      form['patient[age]'] = rand(100)
      form['patient[height]'] = 140 + rand(70)
      form['patient[body_surface_area]'] = 0

      # Click some random Checkboxes
      form.checkboxes.sample(rand(23)).each do |cb| cb.check end
    end

    # Save the patient
    total += bm.report ('Save patient') { @agent.page.form.submit }

    total
  end
end

Benchmark.benchmark(Benchmark::CAPTION, 16, Benchmark::FORMAT, '>total:') do |bm|
  agent = Mechanize.new

  if opts[:proxy_host]
    agent.set_proxy opts[:proxy_host], opts[:proxy_port].to_i
  end

  tresordemo_benchmark = TresordemoBenchmarkSimple.new(agent, opts[:host], opts[:port] || 80)

  begin
    total = tresordemo_benchmark.do(bm)

    9.times do
      total += tresordemo_benchmark.do(bm)
    end

    [total]
  rescue Mechanize::ResponseCodeError => e
    puts e.page.body
  rescue Exception => e
    puts e
  end
end