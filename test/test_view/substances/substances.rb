#!/usr/bin/env ruby
# ODDB::View::Substances::TestSubstances -- oddb.org -- 05.04.2011 -- mhatakeyama@ywesee.com

$: << File.expand_path("../../../src", File.dirname(__FILE__))

require 'test/unit'
require 'flexmock'
require 'view/substances/substances'

module ODDB
	module View
    module Substances

class TestList < Test::Unit::TestCase
  include FlexMock::TestCase
  def setup
    @lnf     = flexmock('lookandfeel', 
                        :lookup     => 'lookup',
                        :attributes => {},
                        :event_url  => 'event_url',
                        :_event_url => '_event_url',
                        :base_url   => 'base_url'
                       )
    state    = flexmock('state', 
                        :interval  => 'interval',
                        :intervals => ['interval']
                       )
    @session = flexmock('session', 
                        :lookandfeel => @lnf,
                        :event       => 'event',
                        :state       => state
                       )
    @model   = flexmock('model', :pointer => 'pointer')
    @list    = ODDB::View::Substances::List.new([@model], @session)
  end
  def test_name
    assert_kind_of(ODDB::View::PointerLink, @list.name(@model, @session))
  end
end

    end # Substances
	end # View
end # ODDB