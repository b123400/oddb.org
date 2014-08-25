#!/usr/bin/env ruby
# encoding: utf-8
# ODDB::TestSession -- oddb.org -- 01.07.2012 -- yasaka@ywesee.com
# ODDB::TestSession -- oddb.org -- 24.06.2011 -- mhatakeyama@ywesee.com
# ODDB::TestSession -- oddb.org -- 22.10.2002 -- hwyss@ywesee.com

$: << File.expand_path('..', File.dirname(__FILE__))
$: << File.expand_path("../../src", File.dirname(__FILE__))

gem 'minitest'
require 'minitest/autorun'
require 'flexmock'
require 'stub/config'
require 'util/session'

module ODDB
  class TestSession <Minitest::Test
    include FlexMock::TestCase
    def setup
      @unknown_user = flexmock('unknown_user',
                               :valid? => false)
      @app = flexmock('app',
                      :unknown_user     => @unknown_user,
                      :sorted_fachinfos => [],
                      :sorted_feedbacks => [],
                      :package_by_ean13 => 'package',)
      @validator = flexmock('validator',
                            :reset_errors => 'reset_errors',
                            :validate     => 'validate')
      @session = ODDB::Session.new('key', @app, @validator)
    end
    def test_login_token
      @session.set_cookie_input(:email, 'email')
      @session.set_cookie_input(:remember, 'remember')
      user_via_token = flexmock('user_via_token',
                                :generate_token => 'generate_token')
      flexmock(@app, :login_token => user_via_token)
      assert_equal(user_via_token, @session.login_token)
    end
    def test_active_state
      @session.set_cookie_input(:email, 'email')
      @session.set_cookie_input(:remember, 'remember')
      user = flexmock('user',
                      :generate_token => 'generate_token',
                      :valid?         => true,
                      :allowed?       => true)
      flexmock(@app, :login_token => user)
      assert_kind_of(ODDB::State::Drugs::Init, @session.active_state)
    end
    def test_allowed?
      flexmock(@unknown_user, :allowed? => true)
      assert_equal(true, @session.allowed?('args'))
    end
    def test_event
      @session.lookandfeel
      assert_equal(:home, @session.event)
    end
    def test_event__else
      assert_equal(:home, @session.event)
    end
    def test_expired?
      assert_equal(false, @session.expired?)
    end
    def test_limit_queries
      @session.instance_eval('@remote_ip = "remote_ip"')
      @session.instance_eval('@process_start = 0')
      ODDB::Session.class_eval('@@requests = {"remote_ip" => [0,1,2,3,4,5,6]}')
      flexmock(@session.state, :limited? => true)
      assert_equal(nil, @session.limit_queries)
    end
    def test_login
      user = flexmock('user',
                      :generate_token => 'generate_token',
                      :email          => 'email')
      flexmock(@app, :login => user)
      assert_equal(user, @session.login)
    end
    def test_login__with_remember_me
      @session.should_receive(:cookie_set_or_get).with(:remember_me).and_return(true)
      user = flexmock('user',
                      :generate_token => 'generate_token',
                      :email          => 'email')
      flexmock(@app, :login => user)
      assert_equal(user, @session.login)
    end
    def test_logout
      flexmock(@unknown_user,
               :yus_session  => 'yus_session',
               :remove_token => 'remove_token')
      flexmock(@app, :logout => 'logout')
      assert_kind_of(ODDB::State::Drugs::Init, @session.logout)
    end
    def test_process
      request = flexmock('request',
                         :unparsed_uri   => 'unparsed_uri',
                         :user_agent     => "",
                         :request_method => 'request_method',
                         :params         => ['params'],
                         :cookies        => 'cookies')
      assert_equal('', @session.process(request))
    end
    def test_process__no_change_in_logged_in_user_entity
      # login
      user = flexmock('user',
                      :generate_token => 'generate_token',
                      :email          => 'email',
                      :valid?         => true,
                      :allowed?       => true)
      user_via_token = flexmock('user_via_token',
                      :generate_token => 'generate_token',
                      :email          => 'email')
      flexmock(@app,
               :login       => user,
               :login_token => user_via_token) # => called via SBSM::Session#process
      @session.login
      # process
      request = flexmock('request',
                         :unparsed_uri   => 'unparsed_uri',
                         :user_agent     => '',
                         :request_method => 'request_method',
                         :params         => ['params'],
                         :cookies        => 'cookies')
      @session.process(request)
      assert_equal('user', @session.user.flexmock_name)
    end
    def test_add_to_interaction_basket
      expected = ["object"]
      assert_equal(expected, @session.add_to_interaction_basket('object'))
    end
    def test_clear_interaction_basket
      assert_equal([], @session.clear_interaction_basket)
    end
    def test_currency
      assert_equal('CHF', @session.currency)
    end
    def test_get_currency_rate
      flexmock(@app, :get_currency_rate => 'get_currency_rate')
      assert_equal('get_currency_rate', @session.get_currency_rate('CHF'))
    end
    def test_interaction_basket
      @session.should_receive(:user_input).with(:substance_ids).and_return(nil)
      assert_equal([], @session.interaction_basket)
    end
    def test_interaction_basket_count
      assert_equal(0, @session.interaction_basket_count)
    end
    def test_interaction_basket_ids
      assert_equal('', @session.interaction_basket_ids)
    end
    def test_interaction_basket_link
      expected = "http://www.oddb.org/de/gcc/interaction_basket/substance_ids/"
      assert_equal(expected, @session.interaction_basket_link)
    end
    def test_analysis_alphabetical
      flexmock(@app, :search_analysis_alphabetical => 'search_analysis_alphabetical')
      assert_equal('search_analysis_alphabetical', @session.analysis_alphabetical('range'))
    end
    def test_migel_alphabetical
      flexmock(@app, :search_migel_alphabetical => 'search_migel_alphabetical')
      assert_equal('search_migel_alphabetical', @session.migel_alphabetical('range'))
    end
    def test_navigation
      expected = [
        ODDB::State::User::Preferences,
        :help_link,
        :faq_link,
        ODDB::State::Admin::Login,
        ODDB::State::User::YweseeContact,
        ODDB::State::Drugs::Init]
      assert_equal(expected, @session.navigation)
    end
    def test_search_exact_indication
      flexmock(@app, :search_exact_indication => 'search_exact_indication')
      assert_equal('search_exact_indication', @session.search_exact_indication('query'))
    end
    def test_search_interactions
      flexmock(@app, :search_interactions => 'search_interactions')
      assert_equal('search_interactions', @session.search_interactions('query'))
    end
    def test_search_migel_products
      flexmock(@app, :search_migel_products => 'search_migel_products')
      assert_equal('search_migel_products', @session.search_migel_products('query'))
    end
    def test_search_substances
      flexmock(@app, :search_substances => 'search_substances')
      assert_equal('search_substances', @session.search_substances('query'))
    end
    def test_set_persistent_user_input
      assert_equal('value', @session.set_persistent_user_input('key', 'value'))
    end
    def test_search_oddb
      flexmock(@app, :search_oddb => 'search_oddb')
      assert_equal('search_oddb', @session.search_oddb('query'))
    end
    def test_reset_query_limit
      # This is a testcase for a class method
      assert_equal({}, ODDB::Session.reset_query_limit)
      assert_equal(nil, ODDB::Session.reset_query_limit('ip'))
    end
    ThreePackages = { '7680576730049' => 'package',
                     '7680193950301' => 'package',
                     '7680353520153' => 'package'}
    UrlForThreePackages = '7680576730049,7680193950301,7680353520153'
    def test_choosen_drugs_for_home_interaction
      @session = ODDB::Session.new('key', @app, @validator)
      @session.instance_eval("@request_path = '/de/gcc/home_interactions/#{UrlForThreePackages}'")
      assert_equal(ThreePackages, @session.choosen_drugs)
    end
    def test_choosen_drugs_for_rezept
      @session = ODDB::Session.new('key', @app, @validator)
      @session.instance_eval("@request_path = '/de/gcc/rezept/ean/#{UrlForThreePackages}'")
      assert_equal(ThreePackages, @session.choosen_drugs)
    end
    def test_choosen_drugs_for_rezept_print
      @session = ODDB::Session.new('key', @app, @validator)
      @session.instance_eval("@request_path = '/de/gcc/print/rezept/ean/#{UrlForThreePackages}'")
      assert_equal(ThreePackages, @session.choosen_drugs)
      @session.instance_eval("@request_path = '/de/gcc/print/rezept/ean/#{UrlForThreePackages}?'")
      assert_equal(ThreePackages, @session.choosen_drugs)
    end
    def test_choosen_drugs_for_rezept_print_with_slashes
      @session = ODDB::Session.new('key', @app, @validator)
      @session.instance_eval("@request_path = '/de/gcc/print/rezept/ean/#{UrlForThreePackages.gsub(',','/')}'")
      assert_equal(ThreePackages, @session.choosen_drugs)
    end
    ZsrAndEAN = "/de/gcc/print/rezept/zsr_J039019/ean/#{UrlForThreePackages.gsub(',','/')}"
    def test_zsr_id
      @session = ODDB::Session.new('key', @app, @validator)
      @session.instance_eval("@request_path = '#{ZsrAndEAN}'")
      assert_equal('J039019', @session.zsr_id)
    end
    def test_choosen_drugs_for_rezept_print_with_zsr
      @session = ODDB::Session.new('key', @app, @validator)
      @session.instance_eval("@request_path = '#{ZsrAndEAN}'")
      assert_equal(ThreePackages, @session.choosen_drugs)
    end
    def test_choosen_drugs_for_interactions_with_atc_and_iksnr
      @session = ODDB::Session.new('key', @app, @validator)
      @session.instance_eval("@request_path = '/de/gcc/home_interactions/58392,7680591310011,L02BA01,58643'")
      expected = {"58392"=>"package",
                  "7680591310011"=>"package", 
                  "L02BA01"=>"package",
                  "58643"=>"package",}
      assert_equal(expected, @session.choosen_drugs)
    end
    def test_choosen_drugs_for_interactions_plus_persistent
      @session = ODDB::Session.new('key', @app, @validator)
      @session.instance_eval("@request_path = '/de/gcc/home_interactions/58392,7680591310011,L02BA01,58643'")
      drugs = {'7680591310012' => 'package_drugs'}
      @session.set_persistent_user_input(:drugs, drugs)
      expected = {"58392"=>"package",
                  "7680591310011"=>"package", 
                  "L02BA01"=>"package",
                  "58643"=>"package",
                  "7680591310012"=>"package_drugs",}
      assert_equal(expected, @session.choosen_drugs)
    end
    def test_handle_gracefully_malformed_url_1
      @session = ODDB::Session.new('key', @app, @validator)
      @session.instance_eval("@request_path = 'de/gcc/prescription/zsr_J039019/zsr_/ean/7680591310011'")
      assert_equal({'7680591310011' => 'package'}, @session.choosen_drugs)
      assert_equal('J039019', @session.zsr_id)
    end
    def test_handle_gracefully_malformed_url_2
      @session = ODDB::Session.new('key', @app, @validator)
      @session.instance_eval("@request_path = 'de/gcc/prescription/zsr_J039019%2f'")
      assert_equal({}, @session.choosen_drugs)
      assert_equal('J039019', @session.zsr_id)
    end
    def test_choosen_drugs_nothing_found
      @session = ODDB::Session.new('key', @app, @validator)
      @session.instance_eval("@request_path = '/de/gcc/home_interactions'")
      @session.set_persistent_user_input(:drugs, nil)
      assert_equal({}, @session.choosen_drugs)
    end
    def test_create_search_url_without_zsr_id
      {
        'create_search_url(:home_interactions, nil)' => 'http://www.oddb.org/de/gcc/home_interactions',
        'create_search_url(:rezept)'                      => 'http://www.oddb.org/de/gcc/rezept',
        'create_search_url()'                             => 'http://www.oddb.org/de/gcc/rezept',
        'create_search_url(:home_interactions, [7680576730049,7680193950301] )' =>
            'http://www.oddb.org/de/gcc/home_interactions/7680576730049/7680193950301'
        }.each {
          |cmd, url|
        @session = ODDB::Session.new('key', @app, @validator)
        res = @session.instance_eval(cmd)
        assert_equal(url,res)
      }
    end
    def test_create_search_url_with_zsr_id
      {
        'create_search_url(:rezept)' =>
          'http://www.oddb.org/de/gcc/rezept/zsr_P123456',
        'create_search_url(:rezept)' =>
          'http://www.oddb.org/de/gcc/rezept/zsr_P123456',
        'create_search_url(:rezept, ["7680495260320"] )' =>
          'http://www.oddb.org/de/gcc/rezept/zsr_P123456/ean/7680495260320',
        'create_search_url(:rezept, [7680516801112,7680576730063] )' =>
            'http://www.oddb.org/de/gcc/rezept/zsr_P123456/ean/7680516801112/7680576730063',
        }.each {
          |cmd, url|
        @session = ODDB::Session.new('key', @app, @validator)
        @session.set_persistent_user_input(:zsr_id, 'P123456')
        res = @session.instance_eval(cmd)
        assert_equal(url,res)
      }
    end
    def test_create_search_url_with_choosen_drugs
      {
        'create_search_url(:rezept)' =>
          'http://www.oddb.org/de/gcc/rezept/zsr_P123456/ean/7680516801112/7680576730063',
        }.each {
          |cmd, url|
        drugs = {'7680516801112' => 'package_drugs',
                 7680576730063 => 'drug 7680576730063'
                 }
        @session = ODDB::Session.new('key', @app, @validator)
        @session.set_persistent_user_input(:zsr_id, 'P123456')
        @session.set_persistent_user_input(:drugs, drugs) 
        res = @session.instance_eval(cmd)
        assert_equal(url,res)
      }
    end
  end
end # ODDB
