require 'slop'
require 'capybara'
require 'capybara/dsl'
require 'selenium/webdriver'
require 'faker'
require 'benchmark'

I18n.enforce_available_locales = false

opts = Slop.parse do
  banner 'Usage: benchmark.rb [options]'

  on 'h=', 'host', 'The host to connect to'
  on 'p=', 'port', 'The port to connect to (default: 80)'
  on 'H=', 'proxy_host', 'HTTP proxy host'
  on 'P=', 'proxy_port', 'HTTP proxy port'
end

Capybara.register_driver :selenium_proxy do |app|
  profile = Selenium::WebDriver::Firefox::Profile.new

  if(opts[:proxy_host])
    profile['network.proxy.no_proxies_on'] = ''
    profile['network.proxy.share_proxy_settings'] = true
    profile['network.proxy.http'] = opts[:proxy_host]
    profile['network.proxy.http_port'] = opts[:proxy_port].to_i
    profile['network.proxy.type'] = 1
  else
    profile['network.proxy.no_proxies_on'] = ''
    profile['network.proxy.share_proxy_settings'] = true
    profile['network.proxy.http'] = ''
    profile['network.proxy.http_port'] = 0
    profile['network.proxy.type'] = 0
  end

  profile['permissions.default.image'] = 2

  Capybara::Selenium::Driver.new(app, :profile => profile)
end

Capybara.default_driver = :selenium_proxy

class TresordemoBenchmarkCapybara
  include Capybara::DSL

  def initialize(host, port)
    @host = host
    @port = port

    # Starts the Browser
    page.title

    sleep 1
  end

  def do(bm)
    total = bm.report ('Visit Home') { visit("http://#{@host}:#{@port}?locale=en") }

    total += bm.report ('Visit Login') { page.first('a').click }

    fill_in('Benutzername', {:with => 'arzt'})

    fill_in('Passwort', {:with => '1234'})

    total += bm.report ('Log in') { click_button('Log in') }

    5.times do
      total += create_new_patient(bm)
    end

    total += bm.report ('Sign out') { click_link('Sign out') }

    total
  end

  def create_new_patient(bm)
    # First click on the menu to get to the patients
    find_link('a', :text => 'Patients').click
    total = bm.report ('List Patients') { all('a', :text => 'Patients')[1].click }

    # Create new patient
    total += bm.report ('New Patient') { click_link('New patient') }

    # Fill in patient data
    fill_in('patient_first_name', :with => Faker::Name.first_name)

    fill_in('patient_last_name', :with => Faker::Name.last_name)

    fill_in('patient_sex', :with => ['male', 'female'][rand(2)])

    fill_in('patient_age', :with => rand(100))

    fill_in('patient_height', :with => 140 + rand(70))

    fill_in('patient_body_surface_area', :with => 0)

    # Click some random Checkboxes
    all('input[type="checkbox"]').select {|i| rand(2) == rand(2)}.each do |cb|
      cb.click
    end

    # Save the patient
    total += bm.report ('Save patient') { click_button('Save') }

    total
  end
end

Benchmark.benchmark(Benchmark::CAPTION, 16, Benchmark::FORMAT, '>total:') do |bm|
  tresordemo_benchmark = TresordemoBenchmarkCapybara.new(opts[:host], opts[:port] || 80)

  begin
    total = tresordemo_benchmark.do(bm)

    9.times do
      total += tresordemo_benchmark.do(bm)
    end

    [total]
  rescue Exception => e
    puts e
  end
end