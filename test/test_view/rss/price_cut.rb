#!/usr/bin/env ruby
# ODDB::View::Rss::TestPriceCut -- oddb.org -- 05.07.2011 -- mhatakeyama@ywesee.com

$: << File.expand_path("../../../src", File.dirname(__FILE__))

require 'test/unit'
require 'flexmock'
require 'view/rss/price_cut'

module ODDB
  module View
    module Rss

class TestPriceCut < Test::Unit::TestCase
  include FlexMock::TestCase
  def setup
    @lnf     = flexmock('lookandfeel', :lookup => 'lookup')
    @session = flexmock('session', :lookandfeel => @lnf)
    @model   = flexmock('model')
    @view    = ODDB::View::Rss::PriceCut.new(@model, @session)
  end
  def test_init
    assert_nil(@view.init)
  end
end

    end # Interactions
  end # View
end # ODDB