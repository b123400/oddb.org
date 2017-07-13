#!/usr/bint_most_precise_doseenv ruby
# encoding: utf-8
# ODDB::View::Drugs::TestResultLimit -- oddb.org -- 14.11.2011 -- mhatakeyama@ywesee.com

$: << File.expand_path('../..', File.dirname(__FILE__))
$: << File.expand_path("../../../src", File.dirname(__FILE__))


require 'minitest/autorun'
require 'flexmock/minitest'
require 'htmlgrid/errormessage'
require 'view/drugs/resultlimit'
require 'htmlgrid/inputradio'
require 'model/registration'
require 'stub/cgi'


module ODDB
  module View
    module Drugs

class TestResultLimitList <Minitest::Test
  def setup
    @lnf     = flexmock('lookandfeel',
                        :format_date => 'format_date',
                        :lookup     => 'lookup',
                        :attributes => {},
                        :_event_url => '_event_url',
                        :result_list_components  => flexmock('result_list_components', :has_value? => false),
                        :has_value? => false,
                        :disabled?  => nil,
                        :enabled?   => nil,
                        :resource   => 'resource',
                        :resource_global => 'resource_global'
                       )
    @state   = flexmock('state', :package_count => 0).by_default
    @session = flexmock('session',
                        :cgi         => CGI.new,
                        :lookandfeel => @lnf,
                        :event       => 'event',
                        :allowed?    => nil,
                        :language    => 'language',
                        :state       => @state,
                        :error       => 'error'
                       )
    minifi   = flexmock('minifi', :pointer => 'pointer')
    commercial_form = flexmock('commercial_form', :language => 'language')
    part     = flexmock('part',
                        :multi   => 'multi',
                        :count   => 'count',
                        :measure => 'measure',
                        :commercial_form => commercial_form
                       )
    registration = flexmock('registration', :iksnr => 'iksnr')
    @model   = flexmock('model',
                        :patent => flexmock('patent', :certificate_number => 'certificate_number', :expiry_date => Date.new(2099,12,31)),
                        :expiration_date => 'expiration_date',
                        :sequence_date    => 'sequence_date',
                        :registration_date => 'registration_date',
                        :revision_date => 'revision_date',
                        :index_therapeuticus => 'index_therapeuticus',
                        :ith_swissmedic => 'ith_swissmedic',
                        :production_science => 'production_science',
                        :preview? => false,
                        :minifi => minifi,
                        :fachinfo_active? => nil,
                        :has_fachinfo?    => nil,
                        :has_patinfo?     => nil,
                        :narcotic?        => nil,
                        :vaccine          => 'vaccine',
                        :name_base        => 'name_base',
                        :commercial_forms => ['commercial_form'],
                        :parts            => [part],
                        :price_exfactory  => 'price_exfactory',
                        :price_public     => 'price_public',
                        :ikscat           => 'ikscat',
                        :sl_entry         => 'sl_entry',
                        :lppv             => 'lppv',
                        :sl_generic_type  => 'sl_generic_type',
                        :pointer          => 'pointer',
                        :localized_name   => 'localized_name',
                        :registration     => registration,
                        :iksnr            => 'iksnr',
                        :seqnr            => 'seqnr',
                        :ikscd            => 'ikscd',
                        :barcode          => 'barcode',
                        :bm_flag          => 'bm_flag',
                       )
    @list    = ODDB::View::Drugs::ResultLimitList.new([@model], @session)
  end
  def test_compose_empty_list
    offset = [0, 0]
    assert_equal([0, 1], @list.compose_empty_list(offset))
  end
  FlexMock::QUERY_LIMIT = 5
  def test_compose_empty_list__package_count
    flexmock(@state, :package_count => 1)
    offset = [0, 0]
    skip("Niklaus does not know why set_colspan in resultlimit returns 14 instead of nil")
    assert_nil(@list.compose_empty_list(offset))
  end
  def test_most_precise_dose
    flexmock(@model,
             :pretty_dose   => nil,
             :active_agents => ['active_agent'],
             :dose          => 'dose'
            )
    assert_equal('dose', @list.most_precise_dose(@model, @session))
  end
end

class TestResultLimitComposite <Minitest::Test
  def setup
    @lnf     = flexmock('lookandfeel',
                        :result_list_components  => flexmock('result_list_components', :has_value? => false),
                        :format_date => 'format_date',
                        :lookup     => 'lookup',
                        :attributes => {},
                        :_event_url => '_event_url',
                        :disabled?  => nil,
                        :base_url   => 'base_url',
                        :enabled?   => nil,
                        :resource   => 'resource',
                        :resource_global => 'resource_global',
                        :format_price    => 'format_price'
                       )
    state    = flexmock('state',
                        :price         => 'price',
                        :package_count => 1
                       )
    @session = flexmock('session',
                        :lookandfeel => @lnf,
                        :cgi         => CGI.new,
                        :state       => state,
                        :zone        => 'zone',
                        :event       => 'event',
                        :allowed?    => nil,
                        :language    => 'language',
                        :remote_ip   => 'remote_ip',
                        :error       => 'error',
                        :warning?    => nil,
                        :error?      => nil,
                        :cookie_set_or_get => 'cookie_set_or_get',
                        :persistent_user_input => 'persistent_user_input'
                       )
    minifi   = flexmock('minifi', :pointer => 'pointer')
    commercial_form = flexmock('commercial_form', :language => 'language')
    part     = flexmock('part',
                        :multi   => 'multi',
                        :count   => 'count',
                        :measure => 'measure',
                        :commercial_form => commercial_form
                       )
    registration = flexmock('registration', :iksnr => 'iksnr')
    @model   = flexmock('model',
                        :sequence_date    => 'sequence_date',
                        :registration_date => 'registration_date',
                        :revision_date => 'revision_date',
                        :expiration_date => 'expiration_date',
                        :index_therapeuticus => 'index_therapeuticus',
                        :ith_swissmedic => 'ith_swissmedic',
                        :production_science => 'production_science',
                        :preview? => false,
                        :patent => flexmock('patent', :certificate_number => 'certificate_number', :expiry_date => Date.new(2099,12,31)),
                        :minifi           => minifi,
                        :fachinfo_active? => nil,
                        :has_fachinfo?    => nil,
                        :has_patinfo?     => nil,
                        :narcotic?        => nil,
                        :vaccine          => 'vaccine',
                        :name_base        => 'name_base',
                        :commercial_forms => ['commercial_form'],
                        :parts            => [part],
                        :price_exfactory  => 'price_exfactory',
                        :price_public     => 'price_public',
                        :ikscat           => 'ikscat',
                        :sl_entry         => 'sl_entry',
                        :lppv             => 'lppv',
                        :sl_generic_type  => 'sl_generic_type',
                        :pointer          => 'pointer',
                        :localized_name   => 'localized_name',
                        :registration     => registration,
                        :iksnr            => 'iksnr',
                        :seqnr            => 'seqnr',
                        :ikscd            => 'ikscd',
                        :barcode          => 'barcode',
                        :bm_flag          => 'bm_flag',
                       )
    @composite = ODDB::View::Drugs::ResultLimitComposite.new([@model], @session)
  end
  def test_export_csv
    assert_kind_of(ODDB::View::Drugs::DivExportCSV, @composite.export_csv(@model))
  end
end

    end # Drugs
  end # View
end # ODDB
